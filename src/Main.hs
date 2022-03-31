{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Main where

import           Control.Concurrent                   (forkIO)
import           Control.Concurrent.ParallelIO.Global
import qualified Control.Exception                    as Exception
import           Control.Lens
import           Control.Monad                        (forever, unless)
import           Control.Monad.Trans                  (liftIO)
import           Crypto.Schnorr
import qualified Data.ByteString                      as BS
import qualified Data.ByteString.Base16               as B16
import qualified Data.ByteString.Char8                as B8
import qualified Data.ByteString.Lazy                 as LazyBytes
import           Data.Either                          (fromRight)
import           Data.Maybe
import           Data.Text                            (Text)
import qualified Data.Text                            as T
import qualified Data.Text.IO                         as T
import           Monomer
import qualified Monomer.Lens                         as L
import qualified Network.Connection                   as Connection
import           Network.Socket
import           Network.WebSockets                   (ClientApp, Connection,
                                                       receiveData, sendClose,
                                                       sendTextData)
import qualified Network.WebSockets                   as WebSockets
import qualified Network.WebSockets.Stream            as Stream
import           TextShow
import           Wuss

data Relay =
  Relay
    { host     :: String
    , port     :: PortNumber
    , readable :: Bool
    , writable :: Bool
    }
  deriving (Eq, Show)

defaultPool =
  [ Relay
      { host = "relayer.fiatjaf.com"
      , port = 443
      , readable = True
      , writable = True
      }
  , Relay
      { host = "nostr-pub.wellorder.net"
      , port = 443
      , readable = True
      , writable = True
      }
  ]

data AppModel =
  AppModel
    { _clickCount    :: Int
    , _myKeyPair     :: Maybe KeyPair
    , _myXOnlyPubKey :: Maybe XOnlyPubKey
    , _pool          :: [Relay]
    , _mySecKeyInput :: Text
    }
  deriving (Eq)

--newtype AppModel = AppModel
data AppEvent
  = AppInit
  | RelayConnected Relay
  | AddRelay Relay
  | AppIncrease
  | RelayDisconnected Relay
  | GenerateKeyPair
  | KeyPairGenerated KeyPair
  | ImportSecKey
  deriving (Eq, Show)

makeLenses 'AppModel

buildUI ::
     WidgetEnv AppModel AppEvent -> AppModel -> WidgetNode AppModel AppEvent
buildUI wenv model =
  case view myKeyPair model of
    Just k ->
      vstack
        [ label "Hello, nostr"
        , label "Haskell GUI Development"
        , spacer
        , hstack
            [ label $ "Click count: " <> showt (model ^. clickCount)
            , spacer
            , button "Increase count" AppIncrease
            ]
        , spacer
        , label "KeyPair"
        , spacer
        , label $ T.pack $ exportKeyPair k
        , spacer
        , label "XOnlyPubKey"
        , spacer
        , label $ T.pack $ exportXOnlyPubKey $ deriveXOnlyPubKey k
        ] `styleBasic`
      [padding 10]
    Nothing ->
      vstack
        [ label "Welcome to nostr"
        , label "Wanna generate a new key pair to start?"
        , spacer
        , hstack
            [ label "Generate new key pair"
            , spacer
            , button "Generate" GenerateKeyPair
            ]
        , spacer
        , hstack
            [ label "or import an existing private key"
            , spacer
            , textField mySecKeyInput `nodeKey` "importmyprivatekey"
            , spacer
            , button "Import" $ ImportSecKey
            ]
        ] `styleBasic`
      [padding 10]

handleEvent ::
     WidgetEnv AppModel AppEvent
  -> WidgetNode AppModel AppEvent
  -> AppModel
  -> AppEvent
  -> [AppEventResponse AppModel AppEvent]
handleEvent wenv node model evt =
  case evt
  --AppInit -> map ($ \r -> Producer $ connectRelay r) defaultPool
        of
    AppInit -> []
    RelayConnected r -> []
    AddRelay r -> [Producer $ connectRelay r]
    AppIncrease -> [Model (model & clickCount +~ 1)]
    GenerateKeyPair -> [Producer generateNewKeyPair]
    --SecKeyGenerated k -> [Model (model & mySecKey .~ Just k)]
    KeyPairGenerated k ->
      [ Model
          model
            {_myKeyPair = Just k, _myXOnlyPubKey = Just $ deriveXOnlyPubKey k}
      ]
    ImportSecKey -> [Model $ importSecKey model]

{-
initRelayConnections :: [Relay] -> IO AppEvent
initRelayConnections p = do
    parallel_ $ fmap connectRelay p
    return RelaysInitialized
-}
connectRelay :: Relay -> (AppEvent -> IO ()) -> IO ()
connectRelay r sendMsg = do
  runSecureClient (host r) (port r) "/" (app r)
  sendMsg $ RelayConnected r

generateNewKeyPair :: (AppEvent -> IO ()) -> IO ()
generateNewKeyPair sendMsg = do
  k <- generateKeyPair
  sendMsg $ KeyPairGenerated k

importSecKey :: AppModel -> AppModel
importSecKey m = m {_myKeyPair = kp, _mySecKeyInput = "", _myXOnlyPubKey = pk}
  where
    kp =
      fmap keyPairFromSecKey $
      maybe Nothing secKey $ decodeHex $ view mySecKeyInput m
    pk = fmap deriveXOnlyPubKey kp

app :: Relay -> ClientApp ()
app r conn = do
  putStrLn $ "Connected to " ++ (host r) ++ ":" ++ (show (port r))
    -- Fork a thread that writes WS data to stdout
  _ <-
    forkIO $
    forever $ do
      msg <- receiveData conn
      liftIO $ T.putStrLn msg
    -- Read from stdin and write to WS
  let loop = do
        line <- T.getLine
        unless (T.null line) $ sendTextData conn line >> loop
  loop
  sendClose conn ("Bye!" :: Text)
  putStrLn $ "Disconnected from " ++ (host r) ++ ":" ++ (show (port r))
    --return (RelayDisconnected r)

createConnection :: Relay -> IO Connection.Connection
createConnection relay = do
  let config = defaultConfig
        --h = host relay
        --p = port relay
    --runSecureClientWithConfig (host relay) (port relay) "/" config options headers app
    {-
    context <- Connection.initConnectionContext
      Exception.bracket
        (Connection.connectTo context (connectionParams h p))
        Connection.connectionClose
        (\connection -> do
          stream <- Stream.makeStream
            (reader config connection)
            (writer connection)
          newClientConnection stream h "/" opts customHeaders
        )
        -}
  context <- Connection.initConnectionContext
  connection <- Connection.connectTo context $ connectionParams relay
  stream <-
    Stream.makeStream
      (fmap Just (Connection.connectionGetChunk connection))
      (maybe
         (return ())
         (Connection.connectionPut connection . LazyBytes.toStrict))
  return connection

tlsSettings :: Connection.TLSSettings
tlsSettings =
  Connection.TLSSettingsSimple
    { Connection.settingDisableCertificateValidation = False
    , Connection.settingDisableSession = False
    , Connection.settingUseServerName = False
    }

connectionParams :: Relay -> Connection.ConnectionParams
connectionParams relay =
  Connection.ConnectionParams
    { Connection.connectionHostname = host relay
    , Connection.connectionPort = port relay
    , Connection.connectionUseSecure = Just tlsSettings
    , Connection.connectionUseSocks = Nothing
    }

main :: IO ()
main = startApp model handleEvent buildUI config
  where
    config =
      [ appWindowTitle "FuTr"
      , appTheme darkTheme
      , appFontDef "Regular" "./assets/fonts/Roboto-Regular.ttf"
      , appInitEvent AppInit
      , appRenderOnMainThread
      ]
    model = AppModel 0 Nothing Nothing [] ""
