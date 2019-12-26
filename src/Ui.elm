module Ui exposing (button, customStyles, text, whiteSpacePre)

import Element exposing (Attribute, Element)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Html
import Html.Attributes
import Ui.Color as Color


button : List (Attribute msg) -> { onPress : Maybe msg, label : Element msg } -> Element msg
button attributes =
    Input.button
        ([ Background.color Color.secondary2
         , Border.shadow
            { blur = 10
            , color = Element.rgba 0 0 0 0.05
            , offset = ( 0, 2 )
            , size = 1
            }
         , Border.rounded 3
         , Element.paddingXY 16 8
         ]
            ++ attributes
        )


text : List (Attribute msg) -> { onChange : String -> msg, label : Element msg, value : String } -> Element msg
text attributes { onChange, label, value } =
    Input.text
        ([] ++ attributes)
        { onChange = onChange
        , label = Input.labelAbove [] label
        , text = value
        , placeholder = Nothing
        }


whiteSpacePre : Element.Attribute msg
whiteSpacePre =
    Html.Attributes.class "wolfadex__elm-text-adventure__white-space_pre" |> Element.htmlAttribute


customStyles : Element msg
customStyles =
    Element.html <|
        Html.node "style"
            []
            [ Html.text """
.wolfadex__elm-text-adventure__white-space_pre > .t {
  white-space: pre-wrap !important;
}""" ]
