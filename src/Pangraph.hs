{-# LANGUAGE OverloadedStrings #-}

module Pangraph (
    -- * Abstract Types
    Pangraph, Edge, Vertex, Attribute,
    Key, Value, VertexID, EdgeID,

    -- * Constructors
    makePangraph, makeEdge, makeVertex,

    -- * Pangraph Getters
    edges, vertices, vertexByID, edgeByID,

    -- * Getters on Vertex and Edge
    edgeAttributes, vertexAttributes,
    edgeEndpoints, edgeID, vertexID,

    -- * Operations on Edge and Vertex
    lookupVertexValues, lookupEdgeValues,

    -- * Utility Operations
    vertexAssocList, edgeAssocList,
    vertexContainsKey,  edgeContainsKey

) where

import Data.Maybe            (catMaybes, mapMaybe, fromMaybe, isJust)
import Data.ByteString.Char8 (pack, unpack)
import Data.Map.Strict       (Map)
import qualified Data.Map.Strict  as Map
import qualified Data.ByteString  as BS
{-| The 'Pangraph' type is abstract and intended to be the core intermediate type between abstract representations of other graph libaries and the results of parsers. -}
data Pangraph = Pangraph
  { vertices' :: Map VertexID Vertex
  , edges' :: Map EdgeID Edge
  , nextEdge' :: EdgeID
  } deriving (Eq)
{-| A 'Vertex' holds `Attributes` and must have a unique `VertexID` to be constructed -}
data Vertex = Vertex
  { vertexID' :: VertexID
  , vertexAttributes' :: [Attribute]
  } deriving (Eq)
{-| 'Edge's also reqiure `Attributes` and a pair of vertices passed as connections. -}
data Edge = Edge
  { edgeID' :: Maybe EdgeID
  , edgeAttributes' :: [Attribute]
  , endpoints' :: (Vertex, Vertex)
  } deriving (Eq)

-- | A type exposed for lookup in the resulting lists.
type EdgeID = Int
-- | A field that is Maybe internally is exposed for lookup.
type VertexID = BS.ByteString
-- | The type alias for storage of fields.
type Attribute = (Key, Value)
-- | The `Key` in tuples that make up `Attributes`.
type Key = BS.ByteString
-- | The `Value` in tuples that make up `Attribute`
type Value = BS.ByteString

type MalformedEdge = (Edge, (Maybe Vertex, Maybe Vertex))

instance Show Pangraph where
  show p = "makePangraph " ++ show (Map.elems (vertices' p)) ++ " " ++ show (Map.elems (edges' p))

instance Show Vertex where
  show (Vertex i as) = unwords ["makeVertex", show i, show as]

instance Show Edge where
  show (Edge i as e) = unwords ["makeEdge", show as, show e]

-- * List based constructors

-- | Takes lists of Vertices and Edges to produce "Just Pangraph" if the graph is correctly formed.
makePangraph :: [Vertex] -> [Edge] -> Maybe Pangraph
makePangraph vs es = case verifyGraph vertexMap es of
  [] -> Just $ Pangraph vertexMap edgeMap (1 + Map.size edgeMap)
  abberrations -> Nothing
  where
    vertexMap :: Map VertexID Vertex
    vertexMap = Map.fromList $ zip (map vertexID vs) vs
    edgeMap :: Map EdgeID Edge
    edgeMap = Map.fromList indexEdges
    indexEdges :: [(EdgeID, Edge)]
    indexEdges = map (\ (i, Edge _ as a) -> (i, Edge (Just i) as a )) $ zip [0..] es

verifyGraph :: Map VertexID Vertex -> [Edge] -> [MalformedEdge]
verifyGraph vs = mapMaybe (\e -> lookupEndpoints (e, edgeEndpoints e))
  where
    lookupEndpoints :: (Edge, (Vertex, Vertex)) ->  Maybe MalformedEdge
    lookupEndpoints (e, (v1,v2)) =
      case (Map.lookup (vertexID v1) vs, Map.lookup (vertexID v2) vs) of
        (Just _ , Just _)  -> Nothing
        (Nothing, Just _)  -> Just (e, (Just v1, Nothing))
        (Just _ , Nothing) -> Just (e, (Nothing, Just v2))
        (Nothing, Nothing) -> Just (e, (Just v1, Just v2))

-- | Edge constructor
makeEdge :: [Attribute] -> (Vertex, Vertex) -> Edge
makeEdge = Edge Nothing

-- | Vetex constuctor
makeVertex :: VertexID -> [Attribute] -> Vertex
makeVertex = Vertex

-- * Pangraph Getters

-- | Returns the Edges from a Pangraph instance
edges :: Pangraph -> [Edge]
edges p = Map.elems $ edges' p

--  | Returns the vertices from a Pangraph instance
vertices :: Pangraph -> [Vertex]
vertices p = Map.elems $ vertices' p

-- | Lookup of the EdgeID in a Pangraph.
-- | Complexity: /O(log n)/
edgeByID :: EdgeID -> Pangraph -> Maybe Edge
edgeByID key p = Map.lookup key $ edges' p

-- | Lookup of the VertexID in a Pangraph.
-- | Complexity: /O(log n)/
vertexByID :: VertexID -> Pangraph -> Maybe Vertex
vertexByID key p = Map.lookup key $ vertices' p

-- * Getters on Edge and Vertex

-- | Returns the Attribute list of an Edge
edgeAttributes :: Edge -> [Attribute]
edgeAttributes = edgeAttributes'

-- | Returns the Attribute list of an Edge
vertexAttributes :: Vertex -> [Attribute]
vertexAttributes = vertexAttributes'

-- | Returns the endpoint Vertices of an Edge
edgeEndpoints :: Edge -> (Vertex, Vertex)
edgeEndpoints = endpoints'

{-| Returns the EdgeID if it has one. `Edge`s are given a new `VetexID` when they are passed and retrived from a `Pangraph`-}
edgeID :: Edge -> Maybe EdgeID
edgeID = edgeID'

-- | Returns a `Vertex`'s`VetexID`
vertexID :: Vertex -> VertexID
vertexID = vertexID'

-- * Operations on Edge and Vertex

-- | Lookup Attributes by `Key`s
-- | Complexity: /O(n)/
lookupVertexValues :: Key -> Vertex -> Maybe Value
lookupVertexValues k v = lookup k (vertexAttributes v)

-- | Lookup Attributes by `Key`s
-- | Complexity: /O(n)/
lookupEdgeValues :: Key -> Edge -> Maybe Value
lookupEdgeValues k e = lookup k (edgeAttributes e)

-- * Utility Operations
-- | Similar to `vertices` but returns an association list instead
vertexAssocList :: Pangraph -> [(VertexID, Vertex)]
vertexAssocList p = Map.toList $ vertices' p

-- | Simlar to `edges` but returns an association list instead
edgeAssocList :: Pangraph -> [(EdgeID, Edge)]
edgeAssocList p = Map.toList $ edges' p

-- | Returns a Bool representing whether a `Key` is present.
-- | Complexity /O(n)/
edgeContainsKey :: Key -> Edge -> Bool
edgeContainsKey k e = isJust $ lookupEdgeValues k e

-- | Returns a Bool representing whether a `Key` is present.
-- | Complexity /O(n)/
vertexContainsKey :: Key -> Vertex -> Bool
vertexContainsKey k v = isJust $ lookupVertexValues k v
