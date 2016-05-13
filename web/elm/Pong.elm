module Pong where

import Color exposing (green)
import Graphics.Collage exposing (Form, collage, filled, move, rect)
import Graphics.Element exposing (Element, layers)
import Keyboard
import Signal
import Text as T
import Time exposing (Time, fps, inSeconds)
import Window
-- import Html

main : Signal Element
main = Signal.map view gameSignal


-- MODEL

type alias State =
  { x: Float
  }

initialState : State
initialState =
  { x = 0
  }


-- UPDATE

port movePaddle : Signal Float
port movePaddle =
  Signal.map (
    \event ->
      case event of
        PaddlePosition posX -> posX
  ) paddleMovement

type Event = PaddlePosition Float

update : Event -> State -> State
update event state =
  case event of
    PaddlePosition posX -> { state | x = posX }


-- VIEW

view : State -> Element
view state =
  layers [
    collage 440 440 [
      box state.x
    ]
  ]

box : Float -> Form
box x =
  rect (toFloat 100) (toFloat 20)
  |> filled green
  |> move (x, -210)


-- SIGNALS

timeDelta : Signal Time
timeDelta =
  Signal.map inSeconds (fps 40)

gameSignal : Signal State
gameSignal = Signal.foldp update initialState paddleMovement

arrowKeysSignal : Signal Int
arrowKeysSignal =
  Signal.sampleOn timeDelta <|
    Signal.map .x Keyboard.arrows

paddleMovement : Signal Event
paddleMovement =
  Signal.map PaddlePosition (
    Signal.dropRepeats (
      Signal.foldp (\dx oldPosX -> paddlePlacement oldPosX dx) 0.0 arrowKeysSignal
    )
  )


-- HELPER FUNCTIONS

paddlePlacement : Float -> Int -> Float
paddlePlacement posX dx =
  let
    boundary = 440 / 2 - 100 / 2
    tmpX = posX + 4 * toFloat dx
    newPosX =
      if tmpX <= -boundary then -boundary
      else if tmpX >= boundary then boundary
      else tmpX
  in
    newPosX
