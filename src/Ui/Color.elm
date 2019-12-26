module Ui.Color exposing (complement, primary, secondary1, seconday2, white)

import Element exposing (Color)


primary : Color
primary =
    Element.rgb255 25 230 25


secondary1 : Color
secondary1 =
    Element.rgb255 30 159 208


seconday2 : Color
seconday2 =
    Element.rgb255 255 146 28


complement : Color
complement =
    Element.rgb255 255 28 28


white : Color
white =
    Element.rgb255 245 245 245
