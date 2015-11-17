module Main where

import Hans
import Hans.Device

import           Control.Concurrent (forkIO,threadDelay)
import           Control.Monad (forever)
import qualified Data.ByteString.Char8 as S8
import           System.Environment (getArgs)


main :: IO ()
main  =
  do args <- getArgs
     name <- case args of
               [name] -> return (S8.pack name)
               _      -> fail "Expected a device name"

     ns  <- newNetworkStack defaultConfig
     dev <- addDevice ns name defaultDeviceConfig

     addIP4Route ns False
         Route { routeNetwork = IP4Mask (packIP4 192 168 71 10) 24
               , routeType    = Direct
               , routeDevice  = dev }

     addIP4Route ns True
         Route { routeNetwork = IP4Mask (packIP4 192 168 71 10) 0
               , routeType    = Indirect (packIP4 192 168 71 1)
               , routeDevice  = dev
               }

     -- start receiving data
     startDevice dev

     _ <- forkIO $ forever $ do threadDelay 1000000
                                dumpStats (devStats dev)

     processPackets ns
