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

type Event = BoxDx Int

update : Event -> State -> State
update event state =
  case event of
    BoxDx dx ->
      let
        boundary = 440 / 2 - 100 / 2
        tmpX = state.x + 4 * toFloat dx
        newX =
          if tmpX <= -boundary then -boundary
          else if tmpX >= boundary then boundary
          else tmpX
      in
        { state | x = newX }


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
  Signal.map inSeconds (fps 35)

keyboardSignal : Signal Event
keyboardSignal =
  Signal.sampleOn timeDelta <|
    Signal.map BoxDx (Signal.map .x Keyboard.arrows)

gameSignal : Signal State
gameSignal = Signal.foldp update initialState keyboardSignal

