{-# LANGUAGE AllowAmbiguousTypes    #-}
{-# LANGUAGE ConstraintKinds        #-}
{-# LANGUAGE DefaultSignatures      #-}
{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE RankNTypes             #-}
{-# LANGUAGE ScopedTypeVariables    #-}
{-# LANGUAGE TypeFamilies           #-}
{-# LANGUAGE UndecidableInstances   #-}

-- | Type class to work with SscGlobalState.

module Pos.Ssc.Extra.MonadGS
       ( MonadSscGS (..)
       , sscRunGlobalQuery
       , sscRunGlobalModify

       , sscApplyBlocks
       , sscCalculateSeed
       , sscRollback
       , sscVerifyBlocks
       ) where

import           Control.Monad.Except  (ExceptT)
import           Control.Monad.Trans   (MonadTrans)
import           Control.TimeWarp.Rpc  (ResponseT)
import           Serokell.Util         (VerificationRes)
import           Universum

import           Pos.Context           (WithNodeContext)
import           Pos.DHT.Model.Class   (DHTResponseT)
import           Pos.DHT.Real          (KademliaDHT)
import           Pos.Ssc.Class.Storage (SscStorageClass (..))
import           Pos.Ssc.Class.Types   (Ssc (..))
import           Pos.Types.Types       (EpochIndex, NEBlocks, SharedSeed)

class Monad m => MonadSscGS ssc m | m -> ssc where
    getGlobalState    :: m (SscGlobalState ssc)
    setGlobalState    :: SscGlobalState ssc -> m ()
    modifyGlobalState :: (SscGlobalState ssc -> (a, SscGlobalState ssc)) -> m a

    default getGlobalState :: MonadTrans t => t m (SscGlobalState ssc)
    getGlobalState = lift getGlobalState

    default setGlobalState :: MonadTrans t => SscGlobalState ssc -> t m ()
    setGlobalState = lift . setGlobalState

    default modifyGlobalState :: MonadTrans t =>
                                 (SscGlobalState ssc -> (a, SscGlobalState ssc)) -> t m a
    modifyGlobalState = lift . modifyGlobalState

instance MonadSscGS ssc m => MonadSscGS ssc (ReaderT a m) where
instance MonadSscGS ssc m => MonadSscGS ssc (ExceptT a m) where
instance MonadSscGS ssc m => MonadSscGS ssc (ResponseT s m) where
instance MonadSscGS ssc m => MonadSscGS ssc (DHTResponseT s m) where
instance MonadSscGS ssc m => MonadSscGS ssc (KademliaDHT m) where

sscRunGlobalQuery
    :: forall ssc m a.
       MonadSscGS ssc m
    => Reader (SscGlobalState ssc) a -> m a
sscRunGlobalQuery query = runReader query <$> getGlobalState @ssc

sscRunGlobalModify
    :: forall ssc m a .
    MonadSscGS ssc m
    => State (SscGlobalState ssc) a -> m a
sscRunGlobalModify upd = modifyGlobalState $ runState upd

sscRunImpureQuery
    :: forall ssc m a.
       (MonadSscGS ssc m)
    => ReaderT (SscGlobalState ssc) m a -> m a
sscRunImpureQuery query = runReaderT query =<< getGlobalState @ssc

sscCalculateSeed
    :: forall ssc m.
       (MonadSscGS ssc m, SscStorageClass ssc, MonadIO m, WithNodeContext ssc m)
    => EpochIndex -> m (Either (SscSeedError ssc) SharedSeed)
sscCalculateSeed = sscRunImpureQuery . sscCalculateSeedM @ssc

sscApplyBlocks
    :: forall ssc m.
       (MonadSscGS ssc m, SscStorageClass ssc)
    => NEBlocks ssc -> m ()
sscApplyBlocks = sscRunGlobalModify . sscApplyBlocksM @ssc

sscRollback
    :: forall ssc m.
       (MonadSscGS ssc m, SscStorageClass ssc)
    => NEBlocks ssc -> m ()
sscRollback = sscRunGlobalModify . sscRollbackM @ssc

sscVerifyBlocks
    :: forall ssc m.
       (MonadSscGS ssc m, SscStorageClass ssc)
    => Bool -> NEBlocks ssc -> m VerificationRes
sscVerifyBlocks verPure = sscRunGlobalQuery . sscVerifyBlocksM @ssc verPure
