{-# LANGUAGE OverloadedStrings #-}

module Main where

import Conduit
import Data.Conduit.Find
import Test.Hspec

main :: IO ()
main = hspec $ do
    describe "basic tests" $ do
        it "file passes a test" $ do
            res <- test (regular >> not_ executable) "README.md"
            res `shouldBe` True

        it "file fails a test" $ do
            res <- test (not_ regular) "README.md"
            res `shouldBe` False

        it "file fails another test" $ do
            res <- test (regular >> executable) "README.md"
            res `shouldBe` False

        it "finds files" $ do
            xs <- runResourceT $
                findFiles "."
                    (    ignoreVcs
                     >> when_ (name_ "dist") reject
                     >> glob "*.hs"
                     >> not_ (glob "Setup*")
                     >> regular
                     >> not_ executable
                    )
                    $$ sinkList

            "./Data/Conduit/Find.hs" `elem` xs `shouldBe` True
            "./dist/setup-config" `elem` xs `shouldBe` False
            "./Setup.hs" `elem` xs `shouldBe` False
            "./.git/config" `elem` xs `shouldBe` False

        it "finds files with a different ordering" $ do
            xs <- runResourceT $
                findFiles "."
                    (    ignoreVcs
                     >> glob "*.hs"
                     >> not_ (glob "Setup*")
                     -- This applies only to .hs files now, so it won't match
                     -- anything, thus having no effect but burning CPU!
                     >> when_ (name_ "dist") reject
                     >> regular
                     >> not_ executable
                    )
                    $$ sinkList

            "./Data/Conduit/Find.hs" `elem` xs `shouldBe` True
            "./dist/setup-config" `elem` xs `shouldBe` False
            "./Setup.hs" `elem` xs `shouldBe` False
            "./.git/config" `elem` xs `shouldBe` False

        it "finds files using a pre-pass filter" $ do
            xs <- runResourceT $
                findRaw "." True
                    (do ignoreVcs
                        when_ (name_ "dist") reject
                        glob "*.hs"
                        not_ (glob "Setup*")
                        stat
                        regular
                        not_ executable)
                    =$ mapC (entryPath . fst) $$ sinkList

            "./Data/Conduit/Find.hs" `elem` xs `shouldBe` True
            "./dist/setup-config" `elem` xs `shouldBe` False
            "./Setup.hs" `elem` xs `shouldBe` False
            "./.git/config" `elem` xs `shouldBe` False

        it "properly applies post-pass pruning" $ do
            xs <- runResourceT $
                findRaw "." True
                    (do ignoreVcs
                        when_ (depth (>=1)) reject
                        when_ (name_ "dist") reject
                        glob "*.hs"
                        not_ (glob "Setup*")
                        stat
                        regular
                        not_ executable)
                    =$ mapC (entryPath . fst) $$ sinkList

            "./Data/Conduit/Find.hs" `elem` xs `shouldBe` False
            "./dist/setup-config" `elem` xs `shouldBe` False
            "./Setup.hs" `elem` xs `shouldBe` False
            "./.git/config" `elem` xs `shouldBe` False
