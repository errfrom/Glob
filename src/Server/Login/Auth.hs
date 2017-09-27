{-# LANGUAGE OverloadedStrings #-}

module Server.Login.Auth
  ( handleAuthorization ) where

import Network.Socket            (Socket)
import Network.Socket.ByteString (recv, send)
import Data.ByteString           (ByteString)
import Database.MySQL.Simple     (Only(..))
import Login.Logic.Auth          (AuthData(..), AuthResult(..))
import Types.General             (LoginPrimaryData(..))
import Types.ServerAction        (constrAsFlag)
import qualified Data.Binary           as Bin   (decode)
import qualified Data.ByteString.Lazy  as LBS   (fromStrict)
import qualified Crypto.BCrypt         as Crypt (validatePassword)
import qualified Database.MySQL.Simple as MySql

handleAuthorization :: Socket -> IO ByteString
handleAuthorization conn = do
  _      <- send conn "1"
  bsData <- LBS.fromStrict <$> recv conn 200
  let data_ = primaryData (Bin.decode bsData :: AuthData ByteString)
  mPasswHash <- getHashedPassword (email data_)
  let res = case mPasswHash of
              Nothing -> AuthInvalidData
              Just ph -> if (Crypt.validatePassword ph $ passw data_)
                           then AuthCorrectData else AuthInvalidData
  return (constrAsFlag res)

-- Получает хеш пароля по указанному значению
-- поля email. Если пользователь отсутствует в базе,
-- возвращает Nothing.
getHashedPassword :: ByteString -> IO (Maybe ByteString)
getHashedPassword email =
  let query = "SELECT USERS_PASSWORD FROM USERS WHERE USER_EMAIL = ?"
  in do
    conn <- MySql.connect MySql.defaultConnectInfo 
    sqlResult <- MySql.query conn query (Only email) :: IO [Only ByteString]
    return $ case sqlResult of
               [] -> Nothing
               [hashedPassword] -> Just $ fromOnly hashedPassword
