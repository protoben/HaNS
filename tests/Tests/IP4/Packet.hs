{-# LANGUAGE RecordWildCards #-}

module Tests.IP4.Packet where

import Tests.Ethernet (arbitraryMac)
import Tests.Network (arbitraryProtocol)
import Tests.Utils (encodeDecodeIdentity,showReadIdentity)

import Hans.IP4.Packet
import Hans.Lens

import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Short as Sh
import           Data.Word (Word8)
import           Test.QuickCheck
import           Test.Tasty (testGroup,TestTree)
import           Test.Tasty.QuickCheck (testProperty)


-- Packet Generator Support ----------------------------------------------------

arbitraryIP4 :: Gen IP4
arbitraryIP4  =
  do a <- arbitraryBoundedRandom
     b <- arbitraryBoundedRandom
     c <- arbitraryBoundedRandom
     d <- arbitraryBoundedRandom
     return $! packIP4 a b c d


arbitraryIP4Mask :: Gen IP4Mask
arbitraryIP4Mask  =
  do addr <- arbitraryIP4
     bits <- choose (0,32)
     return (IP4Mask addr bits)


arbitraryIdent :: Gen IP4Ident
arbitraryIdent  = arbitraryBoundedRandom


arbitraryPayload :: Int -> Gen L.ByteString
arbitraryPayload len =
  do bytes <- vectorOf len arbitraryBoundedRandom
     return (L.pack bytes)

arbitraryOptionPayload :: Word8 -> Gen Sh.ShortByteString
arbitraryOptionPayload len =
  do bytes <- vectorOf (fromIntegral len) arbitraryBoundedRandom
     return (Sh.pack bytes)


arbitraryIP4Header :: Gen IP4Header
arbitraryIP4Header  =
  do ip4TypeOfService <- arbitraryBoundedRandom
     ip4Ident         <- arbitraryIdent
     ip4TimeToLive    <- arbitraryBoundedRandom
     ip4Protocol      <- arbitraryProtocol
     ip4SourceAddr    <- arbitraryIP4
     ip4DestAddr      <- arbitraryIP4

     -- checksum processing is validated by a different property
     let ip4Checksum = 0

     -- XXX need to generate options that fit within the additional 40 bytes
     -- available
     let ip4Options = []

     -- set the members of the ip4Fragment_ field on the final header
     df  <- arbitraryBoundedRandom
     mf  <- arbitraryBoundedRandom
     off <- choose (0,0x1fff)
     let hdr = IP4Header { ip4Fragment_ = 0, .. }

     return $! set ip4DontFragment df
            $! set ip4MoreFragments mf
            $! set ip4FragmentOffset off hdr


arbitraryIP4Option :: Gen IP4Option
arbitraryIP4Option  =
  do ip4OptionCopied  <- arbitraryBoundedRandom
     ip4OptionClass   <- choose (0,0x3)
     ip4OptionNum     <- choose (0,0x1f)

     ip4OptionData <-
       if ip4OptionNum < 2
          then return Sh.empty
          else do len <- choose (0, 0xff - 2)
                  arbitraryOptionPayload len

     return IP4Option { .. }


arbitraryArpPacket :: Gen ArpPacket
arbitraryArpPacket  =
  do arpOper <- elements [ArpRequest,ArpReply]
     arpSHA  <- arbitraryMac
     arpSPA  <- arbitraryIP4
     arpTHA  <- arbitraryMac
     arpTPA  <- arbitraryIP4
     return ArpPacket { .. }


-- Packet Properties -----------------------------------------------------------

packetTests :: TestTree
packetTests  = testGroup "Packet"
  [ testProperty "IP4 Address encode/decode" $
    encodeDecodeIdentity putIP4 getIP4 arbitraryIP4

  , let get =
          do (hdr,20,0) <- getIP4Packet
             return hdr

        put hdr =
             putIP4Header hdr 0

     in testProperty "Header encode/decode" $
        encodeDecodeIdentity put get arbitraryIP4Header

  , testProperty "Option encode/decode" $
    encodeDecodeIdentity putIP4Option getIP4Option arbitraryIP4Option

  , testProperty "Arp Message encode/decode" $
    encodeDecodeIdentity putArpPacket getArpPacket arbitraryArpPacket

  , testProperty "IP4 Addr read/show" $
    showReadIdentity showIP4 readIP4 arbitraryIP4

  , testProperty "IP4 Mask read/show" $
    showReadIdentity showIP4Mask readIP4Mask arbitraryIP4Mask
  ]
