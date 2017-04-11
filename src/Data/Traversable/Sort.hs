{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeOperators         #-}

{-# OPTIONS_GHC -fplugin=GHC.TypeLits.Normalise #-}

module Data.Traversable.Sort where

import           GHC.TypeLits

class IndexedHeap f a where
    merge :: f n a -> f m a -> f (n + m) a
    empty :: f 0 a
    minView :: f (1 + n) a -> (a, f n a)
    singleton :: a -> f 1 a

data Sort f a r where
    Sort :: (forall n. f (m + n) a -> (f n a, r))
         -> !(f m a)
         -> Sort f a r

instance Functor (Sort f x) where
  fmap f (Sort g h) =
    Sort (\h' -> case g h' of (remn, r) -> (remn, f r)) h
  {-# INLINE fmap #-}

instance IndexedHeap f x => Applicative (Sort f x) where
  pure x = Sort (\h -> (h, x)) empty
  {-# INLINE pure #-}

  (Sort f (xs :: f m x) :: Sort f x (a -> b)) <*> Sort g (ys :: f n x) =
    Sort h (merge xs ys)
    where
      h :: forall o . f ((m + n) + o) x -> (f o x, b)
      h v = case f v of { (v', a) ->
                case g v' of { (v'', b) ->
                  (v'', a b)}}
  {-# INLINABLE (<*>) #-}

liftSort :: IndexedHeap f x => x -> Sort f x x
liftSort a = Sort (\h -> case minView h of (x, h') -> (h', x)) (singleton a)
{-# INLINABLE liftSort #-}

runSort :: forall x a f. Sort f x a -> a
runSort (Sort (f :: f (m + 0) x -> (f 0 x, a)) xs) = snd $ f xs

sortTraversable :: (IndexedHeap f a, Traversable t) => p f -> t a -> t a
sortTraversable (_ :: p f) = runSort . traverse (liftSort :: IndexedHeap f x => x -> Sort f x x)
{-# INLINABLE sortTraversable #-}

sortTraversal :: IndexedHeap f a => ((a -> Sort f a a) -> t -> Sort f a t) -> t -> t
sortTraversal trav = runSort . trav liftSort
{-# INLINABLE sortTraversal #-}