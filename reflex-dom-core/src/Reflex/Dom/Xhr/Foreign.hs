{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE JavaScriptFFI #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Reflex.Dom.Xhr.Foreign (
    XMLHttpRequest
  , XMLHttpRequestResponseType(..)
  , module Reflex.Dom.Xhr.Foreign
) where

import Control.Exception (throwIO)
import Control.Monad.IO.Class (MonadIO(..))
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.ByteString (ByteString)
import GHCJS.DOM.Enums
import GHCJS.DOM.EventM (EventM, on)
import GHCJS.DOM.EventTarget (dispatchEvent)
import GHCJS.DOM.Types hiding (Text, ByteString)
import GHCJS.DOM.XMLHttpRequest
-- import GHCJS.Types
import Prelude hiding (error)
import Reflex.Dom.Xhr.Exception
import Reflex.Dom.Xhr.ResponseType
import Language.Javascript.JSaddle.Types (ghcjsPure)
import qualified Language.Javascript.JSaddle.Monad as JS (catch)
import qualified GHCJS.Buffer as JS
       (createFromArrayBuffer, toByteString)
import qualified JavaScript.TypedArray.ArrayBuffer as JS
       (unsafeFreeze, MutableArrayBuffer)

xmlHttpRequestNew :: MonadJSM m => m XMLHttpRequest
xmlHttpRequestNew = newXMLHttpRequest

xmlHttpRequestOpen ::
                   (ToJSString method, ToJSString url, ToJSString user, ToJSString password, MonadJSM m) =>
                     XMLHttpRequest -> method -> url -> Bool -> user -> password -> m ()
xmlHttpRequestOpen request method url async user password = open request method url async (Just user) (Just password)

convertException :: XHRError -> XhrException
convertException e = case e of
  XHRError -> XhrException_Error
  XHRAborted -> XhrException_Aborted

class IsXhrPayload a where
  sendXhrPayload :: MonadJSM m => XMLHttpRequest -> a -> m ()

instance IsXhrPayload () where
  sendXhrPayload xhr _ = send xhr

instance IsXhrPayload String where
  sendXhrPayload = sendString

instance IsXhrPayload Text where
  sendXhrPayload = sendString

instance IsXhrPayload FormData where
  sendXhrPayload = sendFormData

instance IsXhrPayload Document where
  sendXhrPayload = sendDocument

instance IsXhrPayload Blob where
  sendXhrPayload = sendBlob

newtype XhrPayload = XhrPayload { unXhrPayload :: JSVal }

-- This used to be a non blocking call, but now it uses an interruptible ffi
xmlHttpRequestSend :: IsXhrPayload payload => XMLHttpRequest -> payload -> JSM ()
xmlHttpRequestSend self p = sendXhrPayload self p `JS.catch` (liftIO . throwIO . convertException)


xmlHttpRequestSetRequestHeader :: (ToJSString header, ToJSString value, MonadJSM m)
                               => XMLHttpRequest -> header -> value -> m ()
xmlHttpRequestSetRequestHeader = setRequestHeader

xmlHttpRequestAbort :: MonadJSM m => XMLHttpRequest -> m ()
xmlHttpRequestAbort = abort

xmlHttpRequestGetAllResponseHeaders :: MonadJSM m => XMLHttpRequest -> m Text
xmlHttpRequestGetAllResponseHeaders = getAllResponseHeaders

xmlHttpRequestGetResponseHeader :: (ToJSString header, MonadJSM m)
                                => XMLHttpRequest -> header -> m Text
xmlHttpRequestGetResponseHeader self header = fromMaybe "" <$> getResponseHeader self header

xmlHttpRequestOverrideMimeType :: (ToJSString override, MonadJSM m) => XMLHttpRequest -> override -> m ()
xmlHttpRequestOverrideMimeType = overrideMimeType

xmlHttpRequestDispatchEvent :: (IsEvent evt, MonadJSM m) => XMLHttpRequest -> evt -> m Bool
xmlHttpRequestDispatchEvent = dispatchEvent

xmlHttpRequestOnabort :: XMLHttpRequest -> EventM XMLHttpRequest XMLHttpRequestProgressEvent () -> JSM (JSM ())
xmlHttpRequestOnabort = (`on` abortEvent)

xmlHttpRequestOnerror :: XMLHttpRequest -> EventM XMLHttpRequest XMLHttpRequestProgressEvent () -> JSM (JSM ())
xmlHttpRequestOnerror = (`on` error)

xmlHttpRequestOnload :: XMLHttpRequest -> EventM XMLHttpRequest XMLHttpRequestProgressEvent () -> JSM (JSM ())
xmlHttpRequestOnload = (`on` load)

xmlHttpRequestOnloadend :: XMLHttpRequest -> EventM XMLHttpRequest ProgressEvent () -> JSM (JSM ())
xmlHttpRequestOnloadend = (`on` loadEnd)

xmlHttpRequestOnloadstart :: XMLHttpRequest -> EventM XMLHttpRequest ProgressEvent () -> JSM (JSM ())
xmlHttpRequestOnloadstart = (`on` loadStart)

xmlHttpRequestOnprogress :: XMLHttpRequest -> EventM XMLHttpRequest XMLHttpRequestProgressEvent () -> JSM (JSM ())
xmlHttpRequestOnprogress = (`on` progress)

xmlHttpRequestOntimeout :: XMLHttpRequest -> EventM XMLHttpRequest ProgressEvent () -> JSM (JSM ())
xmlHttpRequestOntimeout = (`on` timeout)

xmlHttpRequestOnreadystatechange :: XMLHttpRequest -> EventM XMLHttpRequest Event () -> JSM (JSM ())
xmlHttpRequestOnreadystatechange = (`on` readyStateChange)

xmlHttpRequestSetTimeout :: MonadJSM m => XMLHttpRequest -> Word -> m ()
xmlHttpRequestSetTimeout = setTimeout

xmlHttpRequestGetTimeout :: MonadJSM m => XMLHttpRequest -> m Word
xmlHttpRequestGetTimeout = getTimeout

xmlHttpRequestGetReadyState :: MonadJSM m => XMLHttpRequest -> m Word
xmlHttpRequestGetReadyState = getReadyState

xmlHttpRequestSetWithCredentials :: MonadJSM m => XMLHttpRequest -> Bool -> m ()
xmlHttpRequestSetWithCredentials = setWithCredentials

xmlHttpRequestGetWithCredentials :: MonadJSM m => XMLHttpRequest -> m Bool
xmlHttpRequestGetWithCredentials = getWithCredentials

xmlHttpRequestGetUpload :: MonadJSM m => XMLHttpRequest -> m (Maybe XMLHttpRequestUpload)
xmlHttpRequestGetUpload = fmap Just . getUpload

xmlHttpRequestGetResponseText :: (FromJSString result, MonadJSM m) => XMLHttpRequest -> m (Maybe result)
xmlHttpRequestGetResponseText = getResponseText

xmlHttpRequestGetResponseXML :: MonadJSM m => XMLHttpRequest -> m (Maybe Document)
xmlHttpRequestGetResponseXML = getResponseXML

xmlHttpRequestSetResponseType :: MonadJSM m => XMLHttpRequest -> XMLHttpRequestResponseType -> m ()
xmlHttpRequestSetResponseType = setResponseType

fromResponseType :: XhrResponseType -> XMLHttpRequestResponseType
fromResponseType XhrResponseType_Default = XMLHttpRequestResponseType
fromResponseType XhrResponseType_ArrayBuffer = XMLHttpRequestResponseTypeArraybuffer
fromResponseType XhrResponseType_Blob = XMLHttpRequestResponseTypeBlob
fromResponseType XhrResponseType_Text = XMLHttpRequestResponseTypeText

toResponseType :: XMLHttpRequestResponseType -> Maybe XhrResponseType
toResponseType XMLHttpRequestResponseType = Just XhrResponseType_Default
toResponseType XMLHttpRequestResponseTypeArraybuffer = Just XhrResponseType_ArrayBuffer
toResponseType XMLHttpRequestResponseTypeBlob = Just XhrResponseType_Blob
toResponseType XMLHttpRequestResponseTypeText = Just XhrResponseType_Text
toResponseType _ = Nothing

xmlHttpRequestGetResponseType :: MonadJSM m => XMLHttpRequest -> m (Maybe XhrResponseType)
xmlHttpRequestGetResponseType = fmap toResponseType . getResponseType

xmlHttpRequestGetStatus :: MonadJSM m => XMLHttpRequest -> m Word
xmlHttpRequestGetStatus = getStatus

xmlHttpRequestGetStatusText :: MonadJSM m => FromJSString result => XMLHttpRequest -> m result
xmlHttpRequestGetStatusText = getStatusText

xmlHttpRequestGetResponseURL :: (FromJSString result, MonadJSM m) => XMLHttpRequest -> m result
xmlHttpRequestGetResponseURL = getResponseURL

xmlHttpRequestGetResponse :: MonadJSM m => XMLHttpRequest -> m (Maybe XhrResponseBody)
xmlHttpRequestGetResponse xhr = do
  mr <- getResponse xhr
  rt <- xmlHttpRequestGetResponseType xhr
  case rt of
       Just XhrResponseType_Blob -> fmap XhrResponseBody_Blob <$> castTo Blob mr
       Just XhrResponseType_Text -> Just . XhrResponseBody_Text <$> xmlHttpRequestGetStatusText xhr
       Just XhrResponseType_Default -> Just . XhrResponseBody_Text <$> xmlHttpRequestGetStatusText xhr
       Just XhrResponseType_ArrayBuffer -> Just . XhrResponseBody_ArrayBuffer <$> bsFromArrayBuffer (pFromJSVal mr)
       _ -> return Nothing

bsFromArrayBuffer :: MonadJSM m => JS.MutableArrayBuffer -> m ByteString
bsFromArrayBuffer ab = liftJSM $ JS.unsafeFreeze ab >>=
    ghcjsPure . JS.createFromArrayBuffer >>= ghcjsPure . JS.toByteString 0 Nothing
