module Ui exposing (button, buttonPlain, text, whiteSpacePre)

import Element exposing (Attribute, Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes
import Ui.Color as Color


button : List (Attribute msg) -> { onPress : msg, label : Element msg } -> Element msg
button attributes { onPress, label } =
    Input.button
        ([ Background.color (Element.rgb255 153 153 153)
         , Border.shadow
            { blur = 10
            , color = Element.rgba 0 0 0 0.05
            , offset = ( 0, 2 )
            , size = 1
            }
         , Font.color Color.shadeLight
         , Border.rounded 3
         , Element.paddingXY 16 8
         , button3D
         ]
            ++ attributes
        )
        { onPress = Just onPress
        , label = label
        }


buttonPlain : List (Attribute msg) -> { onPress : msg, label : Element msg } -> Element msg
buttonPlain attributes { onPress, label } =
    Input.button
        ([ Element.paddingXY 16 8
         , Font.underline
         ]
            ++ attributes
        )
        { onPress = Just onPress
        , label = label
        }


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


button3D : Element.Attribute msg
button3D =
    Html.Attributes.class "three-d" |> Element.htmlAttribute
