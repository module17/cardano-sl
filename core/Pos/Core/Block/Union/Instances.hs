-- | United miscellaneous functionality.

module Pos.Core.Block.Union.Instances
       ( getBlockHeader
       , blockHeader
       ) where

import           Universum

import           Control.Lens (Getter, choosing, lens, to)
import qualified Data.Text.Buildable as Buildable

import           Pos.Binary.Class (Bi)
import           Pos.Core.Block.Blockchain (GenericBlock (..))
import           Pos.Core.Block.Genesis ()
import           Pos.Core.Block.Main ()
import           Pos.Core.Block.Union.Types (Block, BlockHeader, ComponentBlock (..),
                                             blockHeaderHash)
import           Pos.Core.Class (HasDifficulty (..), HasEpochIndex (..), HasEpochOrSlot (..),
                                 HasHeaderHash (..), HasPrevBlock (..), IsHeader, IsMainHeader (..))
import           Pos.Core.Slotting.Types (EpochOrSlot (..))

----------------------------------------------------------------------------
-- Buildable
----------------------------------------------------------------------------

instance Bi (BlockHeader v) =>
         Buildable (BlockHeader v) where
    build = either Buildable.build Buildable.build

----------------------------------------------------------------------------
-- HasHeaderHash
----------------------------------------------------------------------------

instance Bi (BlockHeader v) =>
         HasHeaderHash (BlockHeader v) where
    headerHash = blockHeaderHash

instance Bi (BlockHeader v) =>
         HasHeaderHash (Block v) where
    headerHash = blockHeaderHash . getBlockHeader

-- | Take 'BlockHeader' from either 'GenesisBlock' or 'MainBlock'.
getBlockHeader :: Block v -> BlockHeader v
getBlockHeader = bimap _gbHeader _gbHeader

blockHeader :: Getter (Block v) (BlockHeader v)
blockHeader = to getBlockHeader

instance HasHeaderHash (ComponentBlock a) where
    headerHash (ComponentBlockGenesis genesisHeader) = headerHash genesisHeader
    headerHash (ComponentBlockMain mainHeader _)     = headerHash mainHeader

----------------------------------------------------------------------------
-- HasDifficulty
----------------------------------------------------------------------------

instance HasDifficulty (BlockHeader v) where
    difficultyL = choosing difficultyL difficultyL

instance HasDifficulty (Block v) where
    difficultyL = choosing difficultyL difficultyL

----------------------------------------------------------------------------
-- IsHeader
----------------------------------------------------------------------------

instance Bi (BlockHeader v) => IsHeader (BlockHeader v)

----------------------------------------------------------------------------
-- HasPrevBlock
----------------------------------------------------------------------------

instance HasPrevBlock (ComponentBlock a) where
    prevBlockL = lens getter setter
      where
        getter (ComponentBlockGenesis genesisHeader) = genesisHeader ^. prevBlockL
        getter (ComponentBlockMain mainHeader _)     = mainHeader ^. prevBlockL
        setter (ComponentBlockGenesis genesisHeader) e =
            ComponentBlockGenesis (genesisHeader & prevBlockL .~ e)
        setter (ComponentBlockMain mainHeader payload) e =
            ComponentBlockMain (mainHeader & prevBlockL .~ e) payload

----------------------------------------------------------------------------
-- HasEpochIndex
----------------------------------------------------------------------------

instance HasEpochIndex (ComponentBlock a) where
    epochIndexL = lens getter setter
        where
            getter (ComponentBlockGenesis genesisHeader) = genesisHeader ^. epochIndexL
            getter (ComponentBlockMain mainHeader _)     = mainHeader ^. epochIndexL
            setter (ComponentBlockGenesis genesisHeader) e =
                ComponentBlockGenesis (genesisHeader & epochIndexL .~ e)
            setter (ComponentBlockMain mainHeader payload) e =
                ComponentBlockMain (mainHeader & epochIndexL .~ e) payload

----------------------------------------------------------------------------
-- HasEpochOrSlot
----------------------------------------------------------------------------

instance HasEpochOrSlot (ComponentBlock a) where
    getEpochOrSlot (ComponentBlockMain a _)  = EpochOrSlot $ Right $ a ^. headerSlotL
    getEpochOrSlot (ComponentBlockGenesis a) = EpochOrSlot $ Left $ a ^. epochIndexL
