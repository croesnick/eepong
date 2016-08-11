module Pong where

import Color exposing (green, rgb)
import Graphics.Collage exposing (Form, Shape, collage, filled, move, rect, oval, toForm)
import Graphics.Element exposing (Element, layers, leftAligned, spacer, container, middle)
import Keyboard
import Text
import Signal
import Time exposing (Time, fps, inSeconds)
import Window

main =
    Signal.map2 display Window.dimensions gameState


-- MODEL and STATE -------------------------------------------------------------


endScore = 2
(gameWidth,gameHeight) = (600,400)
(halfWidth,halfHeight) = (300,200)

type alias Input =
    { space : Bool
    , paddle1 : Int
    , paddle2 : Int
    , delta : Time
    }

type alias Object a =
    { a |
        x : Float,
        y : Float,
        vx : Float,
        vy : Float
    }

type alias Ball =
    Object {}

type alias Player =
    Object { score : Int }

type State = Play | Pause | End

type alias Game =
    { state : State
    , ball : Ball
    , player1 : Player
    , player2 : Player
    }

player : Float -> Player
player x =
    { x=x, y=0, vx=0, vy=0, score=0 }

defaultGame : Bool -> Game
defaultGame startLeft =
  let
    left  = 20-halfWidth
    right = halfWidth-20

    player1_x = if startLeft then left else right
    player2_x = if startLeft then right else left
  in
    { state   = Pause
    , ball    = { x=0, y=0, vx=200, vy=200 }
    , player1 = player (player1_x)
    , player2 = player (player2_x)
    }


-- SIGNALS ---------------------------------------------------------------------


gameState : Signal Game
gameState =
  Signal.foldp stepGame (defaultGame configPort) input
--  Signal.foldp stepGame defaultGame (Signal.merge configPort input)

delta : Signal Time
delta =
  Signal.map inSeconds (fps 35)

input : Signal Input
input =
  Signal.map2 inputMerger localInput remoteInput

localInput : Signal Input
localInput =
  Signal.sampleOn delta <|
    Signal.map3 inputBuilder
      Keyboard.space
      (Signal.map .y Keyboard.arrows)
      delta

remoteInput : Signal Input
remoteInput =
  Signal.map
    (\(space', y') -> {space = space', paddle1 = y', paddle2 = 0, delta = 0} )
    inputPort


-- PORTS -----------------------------------------------------------------------


port inputPort : Signal (Bool, Int)
--port inputPort = Signal.constant (False, 0)

port configPort : Bool

port outputPort : Signal (Bool, Int)
port outputPort =
  Signal.map
    (\{space, paddle1, paddle2, delta} -> (space, paddle1))
    localInput


-- UPDATE ----------------------------------------------------------------------


-- change the direction of a velocity based on collisions
stepV : Float -> Bool -> Bool -> Float
stepV v lowerCollision upperCollision =
  if lowerCollision then
      abs v
  else if upperCollision then
      -(abs v)
  else
      v

-- step the position of an object based on its velocity and a timestep
stepObj : Time -> Object a -> Object a
stepObj t ({x,y,vx,vy} as obj) =
    { obj |
        x = x + vx * t,
        y = y + vy * t
    }

-- move a ball forward, detecting collisions with either paddle
stepBall : Time -> Ball -> Player -> Player -> Ball
stepBall t ({x,y,vx,vy} as ball) player1 player2 =
  if not (ball.x |> near 0 halfWidth)
    then { ball | x = 0, y = 0 }
    else
      stepObj t
        { ball |
            vx =
              stepV vx (ball `within` player1) (ball `within` player2),
            vy =
              stepV vy (y < 7-halfHeight) (y > halfHeight-7)
        }

-- step a player forward, making sure it does not fly off the court
stepPlyr : Time -> Int -> Int -> Player -> Player
stepPlyr t dir points player =
  let player' = stepObj t { player | vy = toFloat dir * 200 }
      y'      = clamp (22-halfHeight) (halfHeight-22) player'.y
      score'  = player.score + points
  in
      { player' | y = y', score = score' }

stepGame : Input -> Game -> Game
stepGame input game =
  let
    {space,paddle1,paddle2,delta} = input
    {state,ball,player1,player2} = game

    score1 =
        if ball.x > halfWidth then 1 else 0

    score2 =
        if ball.x < -halfWidth then 1 else 0

    ball' =
        if state == Play
            then stepBall delta ball player1 player2
            else ball

    player1' = stepPlyr delta paddle1 score1 player1
    player2' = stepPlyr delta paddle2 score2 player2

    player1_won = player1'.score >= endScore
    player2_won = player2'.score >= endScore

    state' =
        if player1_won || player2_won then End
        else if space then Play
        else if score1 /= score2 then Pause
        else state
  in
      { game |
          state   = state',
          ball    = ball',
          player1 = player1',
          player2 = player2'
      }


-- VIEW ------------------------------------------------------------------------


-- helper values
pongGreen = rgb 60 100 60
textGreen = rgb 160 200 160
txt f = leftAligned << f << Text.monospace << Text.color textGreen << Text.fromString
styledText f = leftAligned << f << (Text.typeface ["helvetica"]) << Text.color textGreen << Text.fromString
msg = "SPACE to start, WS and &uarr;&darr; to move"


-- shared function for rendering objects
displayObj : Object a -> Shape -> Form
displayObj obj shape =
    move (obj.x, obj.y) (filled Color.white shape)


-- display a game state
display : (Int,Int) -> Game -> Element
display (w,h) {state,ball,player1,player2} =
  let scores : Element
      scores =
          toString player1.score ++ "  " ++ toString player2.score
            |> txt (Text.height 50)

      player1_won = player1.score >= endScore
      player2_won = player2.score >= endScore

      winner_msg = if player1_won then "Player 1 wins!"
                   else if player2_won then "Player 2 wins!"
                   else "Huh?"
  in
      container w h middle <|
      collage gameWidth gameHeight <|
      if state == End then
        [ winner_msg |> styledText (Text.height 50) |> toForm ]
      else
       [ filled pongGreen   (rect gameWidth gameHeight)
       , displayObj ball    (oval 15 15)
       , displayObj player1 (rect 10 40)
       , displayObj player2 (rect 10 40)
       , toForm scores
           |> move (0, gameHeight/2 - 40)
       , toForm (
            if state == Play then spacer 1 1
            else txt identity msg
         )
         |> move (0, 40 - gameHeight/2)
       ]


-- HELPER FUNCTIONS ------------------------------------------------------------


inputMerger : Input -> Input -> Input
inputMerger local remote =
  let
    space' = local.space || remote.space
    delta' = local.delta
  in
    { space   = space',
      paddle1 = local.paddle1,
      paddle2 = remote.paddle1,
      delta   = delta' }

inputBuilder : Bool -> Int -> Time -> Input
inputBuilder space y delta =
  { space   = space,
    paddle1 = y,
    paddle2 = 0,
    delta   = delta
  }


-- are n and m near each other?
-- specifically are they within c of each other?
near : Float -> Float -> Float -> Bool
near n c m =
    m >= n-c && m <= n+c

-- is the ball within a paddle?
within : Ball -> Player -> Bool
within ball player =
    near player.x 8 ball.x
    && near player.y 20 ball.y
