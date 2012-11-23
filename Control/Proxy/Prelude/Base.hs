-- | General purpose proxies

module Control.Proxy.Prelude.Base (
    -- * Maps
    mapB,
    mapD,
    mapU,
    mapMB,
    mapMD,
    mapMU,
    execB,
    execD,
    execU,
    -- * Filters
    takeB,
    takeB_,
    takeWhileD,
    takeWhileU,
    dropD,
    dropU,
    dropWhileD,
    dropWhileU,
    filterD,
    filterU,
    -- * Lists
    fromListS,
    fromListC,
    -- * Enumerations
    enumFromS,
    enumFromC,
    enumFromToS,
    enumFromToC,
    -- * Closed Adapters
    -- $open
    openU,
    openD
    ) where

import Control.Proxy.Class
import Control.Proxy.Core.Fast (Proxy)
import Control.Proxy.Synonym
import Data.Closed (C)

{-| @(mapB f g)@ applies @f@ to all values going downstream and @g@ to all
    values going upstream.

    Mnemonic: map \'@B@\'idirectional

> mapB f1 g1 >-> mapB f2 g2 = mapB (f2 . f1) (g1 . g2)
>
> mapB id id = idT
-}
mapB :: (Monad m, ProxyP p) => (a -> b) -> (b' -> a') -> b' -> p a' a b' b m r
mapB f g = go where
    go b' = request (g b') ?>= \a -> respond (f a) ?>= go
-- mapB f g = foreverK $ request . g >=> respond . f
{-# SPECIALIZE mapB
 :: (Monad m) => (a -> b) -> (b' -> a') -> b' -> Proxy a' a b' b m r #-}

{-| @(mapD f)@ applies @f@ to all values going \'@D@\'ownstream.

> mapD f1 >-> mapD f2 = mapD (f2 . f1)
>
> mapD id = idT
-}
mapD :: (Monad m, ProxyP p) => (a -> b) -> x -> p x a x b m r
mapD f = go where
    go x = request x ?>= \a -> respond (f a) ?>= go
-- mapD f = foreverK $ request >=> respond . f
{-# SPECIALIZE mapD :: (Monad m) => (a -> b) -> x -> Proxy x a x b m r #-}

{-| @(mapU g)@ applies @g@ to all values going \'@U@\'pstream.

> mapU g1 >-> mapU g2 = mapU (g1 . g2)
>
> mapU id = idT
-}
mapU :: (Monad m, ProxyP p) => (b' -> a') -> b' -> p a' x b' x m r
mapU g = go where
    go b' = request (g b') ?>= \x -> respond x ?>= go
-- mapU g = foreverK $ (request . g) >=> respond
{-# SPECIALIZE mapU :: (Monad m) => (b' -> a') -> b' -> Proxy a' x b' x m r #-}

{-| @(mapMB f g)@ applies the monadic function @f@ to all values going
    downstream and the monadic function @g@ to all values going upstream.

> mapMB f1 g1 >-> mapMB f2 g2 = mapMB (f1 >=> f2) (g2 >=> g1)
>
> mapMB return return = idT
-}
mapMB
 :: (Monad m, ProxyP p) => (a -> m b) -> (b' -> m a') -> b' -> p a' a b' b m r
mapMB f g = go where
    go b' =
        lift_P (g b') ?>= \a' ->
        request a'    ?>= \a  ->
        lift_P (f a ) ?>= \b  ->
        respond b     ?>= go
-- mapMB f g = foreverK $ lift . g >=> request >=> lift . f >=> respond
{-# SPECIALIZE mapMB
 :: (Monad m) => (a -> m b) -> (b' -> m a') -> b' -> Proxy a' a b' b m r #-}

{-| @(mapMD f)@ applies the monadic function @f@ to all values going downstream

> mapMD f1 >-> mapMD f2 = mapMD (f1 >=> f2)
>
> mapMD return = idT
-}
mapMD :: (Monad m, ProxyP p) => (a -> m b) -> x -> p x a x b m r
mapMD f = go where
    go x =
        request x ?>= \a ->
        lift_P (f a) ?>= \b ->
        respond b ?>= go
-- mapMD f = foreverK $ request >=> lift . f >=> respond
{-# SPECIALIZE mapMD :: (Monad m) => (a -> m b) -> x -> Proxy x a x b m r #-}

{-| @(mapMU g)@ applies the monadic function @g@ to all values going upstream

> mapMU g1 >-> mapMU g2 = mapMU (g2 >=> g1)
>
> mapMU return = idT
-}
mapMU :: (Monad m, ProxyP p) => (b' -> m a') -> b' -> p a' x b' x m r
mapMU g = go where
    go b' =
        lift_P (g b') ?>= \a' ->
        request a'    ?>= \x ->
        respond x     ?>= go
-- mapMU g = foreverK $ lift . g >=> request >=> respond
{-# SPECIALIZE mapMU
 :: (Monad m) => (b' -> m a') -> b' -> Proxy a' x b' x m r #-}

{-| @(execB md mu)@ executes @mu@ every time values flow upstream through it,
    and executes @md@ every time values flow downstream through it.

> execB md1 mu1 >-> execB md2 mu2 = execB (md1 >> md2) (mu2 >> mu1)
>
> execB (return ()) = idT
-}
execB :: (Monad m, ProxyP p) => m () -> m () -> a' -> p a' a a' a m r
execB md mu = go where
    go a' =
        lift_P mu  ?>= \_ ->
        request a' ?>= \a ->
        lift_P md  ?>= \_ ->
        respond a  ?>= go
{- execB md mu = foreverK $ \a' -> do
    lift mu
    a <- request a'
    lift md
    respond a -}
{-# SPECIALIZE execB
 :: (Monad m) => m () -> m () -> a' -> Proxy a' a a' a m r #-}

{-| @execD md)@ executes @md@ every time values flow downstream through it.

> execD md1 >-> execD md2 = execD (md1 >> md2)
>
> execD (return ()) = idT
-}
execD :: (Monad m, ProxyP p) => m () -> a' -> p a' a a' a m r
execD md = go where
    go a' =
        request a' ?>= \a ->
        lift_P md  ?>= \_ ->
        respond a  ?>= go
{- execD md = foreverK $ \a' -> do
    a <- request a'
    lift md
    respond a -}
{-# SPECIALIZE execD :: (Monad m) => m () -> a' -> Proxy a' a a' a m r #-}

{-| @execU mu)@ executes @mu@ every time values flow upstream through it.

> execU mu1 >-> execU mu2 = execU (mu2 >> mu1)
>
> execU (return ()) = idT
-}
execU :: (Monad m, ProxyP p) => m () -> a' -> p a' a a' a m r
execU mu = go where
    go a' =
        lift_P mu  ?>= \_ ->
        request a' ?>= \a ->
        respond a  ?>= go
{- execU mu = foreverK $ \a' -> do
    lift mu
    a <- request a'
    respond a -}
{-# SPECIALIZE execU :: (Monad m) => m () -> a' -> Proxy a' a a' a m r #-}

{-| @(takeB n)@ allows @n@ upstream/downstream roundtrips to pass through

> takeB n1 >=> takeB n2 = takeB (n1 + n2)  -- n1 >= 0 && n2 >= 0
>
> takeB 0 = return
-}
takeB :: (Monad m, ProxyP p) => Int -> a' -> p a' a a' a m a'
takeB n0 = go n0 where
    go n
        | n <= 0    = return_P
        | otherwise = \a' ->
             request a' ?>= \a ->
             respond a  ?>= go (n - 1)
-- takeB n = replicateK n $ request >=> respond
{-# SPECIALIZE takeB :: (Monad m) => Int -> a' -> Proxy a' a a' a m a' #-}

-- | 'takeB_' is 'takeB' with a @()@ return value, convenient for composing
takeB_ :: (Monad m, ProxyP p) => Int -> a' -> p a' a a' a m ()
takeB_ n0 = go n0 where
    go n
        | n <= 0    = \_ -> return_P ()
        | otherwise = \a' ->
            request a' ?>= \a ->
            respond a  ?>= go (n - 1)
-- takeB_ n = fmap void (takeB n)
{-# SPECIALIZE takeB_ :: (Monad m) => Int -> a' -> Proxy a' a a' a m () #-}

{-| @takeWhileD p@ allows values to pass downstream so long as they satisfy the
     predicate @p@.

> -- Using the "All" monoid over functions:
> mempty = \_ -> True
> (p1 <> p2) a = p1 a && p2 a
>
> takeWhileD p1 >-> takeWhileD p2 = takeWhileD (p1 <> p2)
>
> takeWhileD mempty = idT
-}
takeWhileD :: (Monad m, ProxyP p) => (a -> Bool) -> a' -> p a' a a' a m ()
takeWhileD p = go where
    go a' =
        request a' ?>= \a ->
        if (p a)
        then respond a ?>= go
        else return_P ()
{-# SPECIALIZE takeWhileD
 :: (Monad m) => (a -> Bool) -> a' -> Proxy a' a a' a m () #-}

{-| @takeWhileU p@ allows values to pass upstream so long as they satisfy the
    predicate @p@.

> takeWhileU p1 >-> takeWhileU p2 = takeWhileU (p1 <> p2)
>
> takeWhileD mempty = idT
-}
takeWhileU :: (Monad m, ProxyP p) => (a' -> Bool) -> a' -> p a' a a' a m ()
takeWhileU p = go where
    go a' =
        if (p a')
        then
            request a' ?>= \a ->
            respond a  ?>= go
        else return_P ()
{-# SPECIALIZE takeWhileU
 :: (Monad m) => (a' -> Bool) -> a' -> Proxy a' a a' a m () #-}

{-| @(dropD n)@ discards @n@ values going downstream

> dropD n1 >-> dropD n2 = dropD (n1 + n2)  -- n2 >= 0 && n2 >= 0
>
> dropD 0 = idT
-}
dropD :: (Monad m, ProxyP p) => Int -> () -> Pipe p a a m r
dropD n0 = \() -> go n0 where
    go n
        | n <= 0    = idT ()
        | otherwise =
            request () ?>= \_ ->
            go (n - 1)
{- dropD n () = do
    replicateM_ n $ request ()
    idT () -}
{-# SPECIALIZE dropD :: (Monad m) => Int -> () -> Proxy () a () a m r #-}

{-| @(dropU n)@ discards @n@ values going upstream

> dropU n1 >-> dropU n2 = dropU (n1 + n2)  -- n2 >= 0 && n2 >= 0
>
> dropU 0 = idT
-}
dropU :: (Monad m, ProxyP p) => Int -> a' -> CoPipe p a' a' m r
dropU n0
    | n0 <= 0   = idT
    | otherwise = go (n0 - 1) where
        go n
            | n <= 0    = \_ -> respond () ?>= idT
            | otherwise = \_ -> respond () ?>= go (n - 1)
{- dropU n a'
    | n <= 0    = idT a'
    | otherwise = do
        replicateM_ (n - 1) $ respond ()
        a'2 <- respond ()
        idT a'2 -}
{-# SPECIALIZE dropU :: (Monad m) => Int -> a' -> Proxy a' () a' () m r #-}

{-| @(dropWhileD p)@ discards values going upstream until one violates the
    predicate @p@.

> -- Using the "Any" monoid over functions:
> mempty = \_ -> False
> (p1 <> p2) a = p1 a || p2 a
>
> dropWhileD p1 >-> dropWhileD p2 = dropWhileD (p1 <> p2)
>
> dropWhileD mempty = idT
-}
dropWhileD :: (Monad m, ProxyP p) => (a -> Bool) -> () -> Pipe p a a m r
dropWhileD p () = go where
    go =
        request () ?>= \a ->
        if (p a)
        then go
        else respond a ?>= idT
{-# SPECIALIZE dropWhileD
 :: (Monad m) => (a -> Bool) -> () -> Proxy () a () a m r #-}

{-| @(dropWhileU p)@ discards values going downstream until one violates the
    predicate @p@.

> dropWhileU p1 >-> dropWhileU p2 = dropWhileU (p1 <> p2)
>
> dropWhileU mempty = idT
-}
dropWhileU :: (Monad m, ProxyP p) => (a' -> Bool) -> a' -> CoPipe p a' a' m r
dropWhileU p = go where
    go a' = if (p a') then respond () ?>= go else idT a'
{-# SPECIALIZE dropWhileU
 :: (Monad m) => (a' -> Bool) -> a' -> Proxy a' () a' () m r #-}

{-| @(filterD p)@ discards values going downstream if they fail the predicate
    @p@

> -- Using the "All" monoid over functions:
> mempty = \_ -> True
> (p1 <> p2) a = p1 a && p2 a
>
> filterD p1 >-> filterD p2 = filterD (p1 <> p2)
>
> filterD mempty = idT
-}
filterD :: (Monad m, ProxyP p) => (a -> Bool) -> () -> Pipe p a a m r
filterD p = \() ->  go where
    go = request () ?>= \a ->
         if (p a)
             then
                 respond a ?>= \_ ->
                 go
             else go
{-# SPECIALIZE filterD
 :: (Monad m) => (a -> Bool) -> () -> Proxy () a () a m r #-}

{-| @(filterU p)@ discards values going upstream if they fail the predicate @p@

> filterU p1 >-> filterU p2 = filterU (p1 <> p2)
>
> filterU mempty = idT
-}
filterU :: (Monad m, ProxyP p) => (a' -> Bool) -> a' -> CoPipe p a' a' m r
filterU p a'0 = go a'0 where
    go a' =
        if (p a')
        then
            request a' ?>= \_ ->
            respond () ?>= go
        else respond () ?>= go
{-# SPECIALIZE filterU
 :: (Monad m) => (a' -> Bool) -> a' -> Proxy a' () a' () m r #-}

{-| Convert a list into a 'Server'

> fromListS xs >=> fromListS ys = fromListS (xs ++ ys)
>
> fromListS [] = return
-}
fromListS :: (Monad m, ProxyP p) => [b] -> () -> Producer p b m ()
fromListS xs = \_ -> foldr (\e a -> respond e ?>= \_ -> a) (return_P ()) xs
-- fromListS xs _ = mapM_ respond xs
{-# INLINE fromListS #-} -- So that foldr/build fusion occurs
{-# SPECIALIZE fromListS :: (Monad m) => [b] -> () -> Proxy C () () b m () #-}

{-| Convert a list into a 'Client'

> fromListC xs >=> fromListC ys = fromListC (xs ++ ys)
>
> fromListC [] = return
-}
fromListC :: (Monad m, ProxyP p) => [a'] -> () -> CoProducer p a' m ()
fromListC xs = \_ -> foldr (\e a -> request e ?>= \_ -> a) (return_P ()) xs
-- fromListC xs _ = mapM_ request xs
{-# INLINE fromListC #-} -- So that foldr/build fusion occurs
{-# SPECIALIZE fromListC :: (Monad m) => [a'] -> () -> Proxy a' () () C m () #-}

-- | 'Server' version of 'enumFrom'
enumFromS :: (Enum b, Monad m, ProxyP p) => b -> () -> Producer p b m r
enumFromS b0 = \_ -> go b0 where
    go b =
        respond b ?>= \_ ->
        go (succ b)
{-# SPECIALIZE enumFromS
 :: (Enum b, Monad m) => b -> () -> Proxy C () () b m r #-}

-- | 'Client' version of 'enumFrom'
enumFromC :: (Enum a', Monad m, ProxyP p) => a' -> () -> CoProducer p a' m r
enumFromC a'0 = \_ -> go a'0 where
    go a' =
        request a' ?>= \_ ->
        go (succ a')
{-# SPECIALIZE enumFromC
 :: (Enum a', Monad m) => a' -> () -> Proxy a' () () C m r #-}

-- | 'Server' version of 'enumFromTo'
enumFromToS
 :: (Enum b, Ord b, Monad m, ProxyP p) => b -> b -> () -> Producer p b m ()
enumFromToS b1 b2 _ = go b1 where
    go b
        | b > b2    = return_P ()
        | otherwise = respond b ?>= \_ -> go (succ b)
{-# SPECIALIZE enumFromToS
 :: (Enum b, Ord b, Monad m) => b -> b -> () -> Proxy C () () b m () #-}

-- | 'Client' version of 'enumFromTo'
enumFromToC
 :: (Enum a', Ord a', Monad m, ProxyP p)
 => a' -> a' -> () -> CoProducer p a' m ()
enumFromToC a1 a2 _ = go a1 where
    go n
        | n > a2 = return_P ()
        | otherwise =
            request n ?>= \_ ->
            go (succ n)
{-# SPECIALIZE enumFromToC
 :: (Enum a', Ord a', Monad m) => a' -> a' -> () -> Proxy a' () () C m () #-}

{- $open
    Use the @open@ functions when you need to embed a proxy with a closed end
    within an open proxy.  For example, the following code will not type-check
    because @fromListS [1..]@  is a 'Server' and has a closed upstream end,
    which conflicts with the 'request' statement before it:

> p () = do
>     request ()
>     fromList [1..] ()

    You fix this by composing 'openU' upstream of it, which turns its closed
    upstream end into an open polymorphic end:

> p () = do
>     request ()
>     (fromList [1..] <-< openU) ()

-}

-- | Compose 'openU' with a closed upstream end to create a polymorphic end
openU :: (Monad m, ProxyP p) => C -> p a' a C () m r
openU _ = go where
    go = respond () ?>= \_ -> go

-- | Compose 'openD' with a closed downstream end to create a polymorphic end
openD :: (Monad m, ProxyP p) => b' -> p () C b' b m r
openD _ = go where
    go = request () ?>= \_ -> go
