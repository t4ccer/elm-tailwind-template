module Main exposing (..)

import Browser
import Html exposing (Html, a, button, div, h1, text)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)


main : Program () Model Msg
main =
    Browser.sandbox { init = init, view = view, update = update }


type alias Model =
    Int


type Msg
    = Increment
    | Decrement


init : Model
init =
    0


update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            model + 1

        Decrement ->
            if model > 0 then
                model - 1

            else
                0


view : Model -> Html Msg
view model =
    div
        [ class "grid m-4" ]
        [ h1 [ class "flex justify-center font-bold text-4xl text-cyan" ] [ text "Elm and Tailwind CSS" ]
        , div [ class "flex justify-center" ] [ viewCounter model ]
        ]


viewCounter : Model -> Html Msg
viewCounter model =
    div
        [ class "flex p-4" ]
        [ button [ class "btn m-4 text-pink", onClick Decrement ] [ text "-" ]
        , div [ class "m-4 font-bold text-xl text-cyan" ] [ text (String.fromInt model) ]
        , button [ class "btn m-4 text-green", onClick Increment ] [ text "+" ]
        ]
