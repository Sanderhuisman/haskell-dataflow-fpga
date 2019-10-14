{-# LANGUAGE OverloadedStrings #-}
module SVGWriter where

import Graphics.Svg

import Data.Text.Internal
import qualified Data.Map as M
import Data.String
import Data.Ratio
import Data.Maybe

import Hardware
import DataFlow
import Graph

scalar :: RealFloat a => a
scalar = 20
leftMargin = 100
topMargin = 50
asOffset = 4 -- the space between the different actor schedules in the graph

svg :: RealFloat a => a -> a -> Element -> Element
svg w h content =
     doctype
  <> with (svg11_ content) [Version_ <<- "1.1", Width_ <<- toText w, Height_ <<- toText h]

-- contents :: Element
-- contents =
--      --rect_   [ X_ <<- "20", Y_ <<- "20",  Width_ <<- "10", Height_ <<- "10", "blue" ->> Fill_]
--      periodicRects 0 0  (0  ,50 ) 10 10 1200
--  <> periodicRects 0 20 (160,200) 40 10 1200
--  <> circle_ [ Cx_ <<- "150", Cy_ <<- "100", R_ <<- "80", Fill_ <<- "green"]
--  <> text_   [ X_ <<- "150", Y_ <<- "125", Font_size_ <<- "60", Text_anchor_ <<- "middle", Fill_ <<- "white"] "SVG"
--  <> txt 0 10 10 "habla"
--  <> txt 0 60 50 "test"
--  <> actor 10 50 "*" (0,50) 10 15 1200


-- rect arguments
-- x: x-coordinate of top left corner
-- y: y-coordinate of top left corner
-- w: width
-- h: height
-- c: color
-- rect :: RealFloat a => a -> a -> a -> a -> Data.Text.Internal.Text -> Element
rect x y w h c = rect_ [X_ <<- toText (scalar * x)
                      , Y_ <<- toText (scalar * y)
                      , Width_ <<- toText (scalar * w)
                      , Height_ <<- toText (scalar * h)
                      , Stroke_ <<- "black"
                      , Stroke_width_ <<- toText (h/15*scalar)
                      , c ->> Fill_
                      ]

-- periodicRects arguments
-- x: x-coordinate
-- y: y-coordinate
-- s: start time
-- p: period
-- w: width of rectangle
-- h: hight of rectangle
-- endX: length of pattern
-- color: color of rectangles
-- periodicRects :: (Enum a, RealFloat a) => a -> a -> (a, a) -> a -> a -> a -> Data.Text.Internal.Text -> Element
periodicRects x y (s,p) w h endX color
  = mconcat [rect x' y w h color | x' <- [s',(s' + p)..endX]]
  where
    s' = (x + s) -- start x + the start time is the start of the printing

-- txt arguments (anchor point is left down cornor)
-- x: x-coordinate of the anchor point
-- y: y-coordinate of the anchor point
-- fontSize: size of text font
-- text: String to print
-- anchor = anchor in this case is as follows:
-- "start" : upper left corner
-- "middle" : top middle
-- "end": upper right corner
txt :: (RealFloat a) => a -> a -> a -> Data.Text.Internal.Text -> String -> Element
txt x y fontSize anchor text 
  = text_ [ X_ <<- toText (scalar * x)
          , Y_ <<- toText (scalar * y + fontSize)
          , Font_size_ <<- toText fontSize
          , Text_anchor_ <<- anchor
          ] (toElement text)

-- line arguments (line between point 1 and 2)
-- x1: x-coordinate of point 1
-- y1: y-coordinate of point 1
-- x2: x-coordinate of point 2
-- y2: y-coordinate of point 2
-- s: stroke pattern
-- c: color of line
line :: (RealFloat a) => a -> a -> a -> a -> a -> Data.Text.Internal.Text -> Element
line x1 y1 x2 y2 s c = line_ [X1_ <<- toText (scalar * x1)
                            , Y1_ <<- toText (scalar * y1)
                            , X2_ <<- toText (scalar * x2)
                            , Y2_ <<- toText (scalar * y2)
                            , Stroke_ <<- c
                            , Stroke_width_ <<- toText 2
                            , Stroke_dasharray_ <<- toText s
                            ]

-- lineWithText (line between point 1 and 2 with text at the bottom)
-- x1: x-coordinate of point 1
-- y1: y-coordinate of point 1
-- x2: x-coordinate of point 2
-- y2: y-coordinate of point 2
-- s: stroke pattern
-- c: color of line
-- fontSize: size of text font
-- t: String to print
lineWithText :: RealFloat a => a -> a -> a -> a -> a -> Data.Text.Internal.Text -> a -> String -> Element
lineWithText x1 y1 x2 y2 s c fontSize text = 
  txt x1 y2 fontSize "middle" text
  <> line x1 y1 x2 y2 s c


-- columnLines: Lines with numbers spanning between start and end
-- x: the X of the upper left corner of the raster
-- y: the Y of the upper left corner of the raster
-- h: the height of the raster (length of lines
-- endX: the X of the end of the raster
-- scale: scale the visual space between the raster lines, and the height of the raster
-- startCount: the starting number of the columnLines
-- stepSize: the step size between the numbers
columnLines :: (Enum a, RealFloat a) => a -> a -> a -> a -> a -> a -> Element
columnLines x y h endX startCount stepSize
  = mconcat [lineWithText x1 y1 x2 y2 s c fontSize t'
            | (x,t) <- zip [x, (x + stepSize)..endX] [startCount, stepSize..]
            , let x1 = x
            , let x2 = x1
            , let y1 = y
            , let y2 = y + h
            , let fontSize = 15
            , let c = "black"
            , let s = (scalar / 15)*2
            , let t' = show (round t)
            ]
{-

-- vline arguments
-- x: x-coordinate of left upper corner of schedule (excluding text)
-- y: y-coordinate of left upper corner of schedule (excluding text)
-- l: length of lines
-- s: stroke pattern
-- m: length of schedule pattern
-- p: period between lines
-- c: color
vlines :: (Enum a, RealFloat a) => a -> a -> a -> a -> a -> a -> Data.Text.Internal.Text -> Element
vlines x y l s m p c = mconcat  [ line x' y1 x' y2 s c
                                | let y1 = y
                                , let y2 = y+l
                                , x' <- [x,x+p..m]
                                ]
-}

-- actor arguments
-- tx: start x of text box
-- y: y-coordinate
-- px: start x coordinate of the periodic printing blocks
-- h: height of row
-- text: actor label
-- startTime: start time of actor
-- period: period of actor
-- exTime:  execution time (width of rectangle)
-- endX: length of text+pattern
actor :: (RealFloat a, Enum a) => a -> a -> a -> a -> a -> String -> (a,a) -> a -> Element
actor tx y px h endX text (startTime,period) exTime
  =  txt tx y (0.8*h*scalar) "start" text 
  <> periodicRects px y (startTime,period) exTime h endX "green"


-- actors arguments  
-- x: x-coordinate of left upper corner of schedule
-- y: y-coordinate of left upper corner of schedule
-- h: hight of schedule blocks
-- m: length of schedule pattern
-- mmap: strict periodic schedule as M.Map with node label as key, and (start time, period, execution time) for each node as element
actors :: (Show l, RealFloat a, Enum a) => a -> a -> a -> a -> M.Map l (Ratio Integer, Ratio Integer, Integer) -> Element
actors x y h endX mmap 
  = columnLines px y th endX 0 tp'
  <> mconcat [actor x y' px h endX (show l) (st,p') ex'
  | ((l,(s,p,ex)),y') <- zip (M.toList mmap) [y,(y+h)..]
  , let p'  = ((fromInteger $ numerator p) / (fromInteger $ denominator p))
  , let s'  = ((fromInteger $ numerator s) / (fromInteger $ denominator s))
  , let st = if s' < 0 then s' + p' else s'
  , let ex' = if ex == 0 then 1 else (fromInteger ex) -- if execution time is 0, print a small line (1)
  ]
  where
    px = x + (fromIntegral $ maximum $ map (length . show) (M.keys mmap)) -- start periods at x + maximum label length
    th = h * (fromIntegral $ M.size mmap + 1) -- size +1 so some extra space beneath 
    tp = maximum $ map (\(_,p,_) -> p) $ M.elems mmap -- max period of all actors
    tp' = (fromInteger $ numerator tp) / (fromIntegral $ denominator tp) -- from Ratio to Rational

--svgSchedule Nothing     = writeFile "../schedules/svg.svg" (show $ svg $ clocklines 50 100)
--svgSchedule (Just mmap) = writeFile "../schedules/svg.svg" (show $ svg $ (clocklines 50 1200) <> (actors 60 60  1200 mmap))
svgSchedule :: (Show l, DFEdges e, Ord l, DFNodes n, Eq (e l)) 
  => Graph (M.Map l (n l)) [e l] -> IO ()
svgSchedule graph
  | isNothing mmap' = writeFile path (show $ svg canvasWidth canvasHeight $ txt startX startY 40 "start" "No schedule")
  | otherwise = writeFile path (show $ svg canvasWidth canvasHeight $ 
    mconcat [actors startX startY height endX mmap
            -- , columnLines cStartX cStartY cHeight cEndX scale startCount stepSize
            ])
  where
    -- Important: everything is scaled by the scaler defined in this file
    canvasHeight = 600
    canvasWidth = 1920
    height = 2 -- height of each row
    startX = 4
    startY = 4
    endX = canvasWidth

    mmap' = strictlyPeriodicScheduleWithExTime graph
    mmap = fromJust mmap'

    path = "../schedules/svg.svg"

{-
svgPrintEx (Just mmap) = writeFile path (show $ svg m l $
  mconcat [ --periodicRects startX startY (startTime, period) exTime height endX color
          --columnLines startX startY height endX startCount stepSize 
          -- actor startX startY (startX + 10) height endX "a" (startTime, period) exTime
          actors startX startY height endX mmap
          -- , txt 10 5 15 "start" "Muh"
          ])
  where
    startX = 4
    startY = 4
    height = 2
    endX = m

    startTime = 2
    period = 10 
    exTime = 5

    color = "green"
    stepSize = 5
    startCount = 0

    fontSize = 15

    m = 1920
    l = 600
    path = "../schedules/svg.svg"
-}
--main :: IO ()
--main = do
--  print $ svg contents