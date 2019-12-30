module Ui.Color exposing
    ( accentDark
    , accentLight
    , danger
    , info
    , primary
    , shadeDark
    , shadeLight
    , success
    , warning
    )

import Element exposing (Color)


primary : Color
primary =
    Element.rgb255 182 167 160


info : Color
info =
    Element.rgb255 69 64 64


success : Color
success =
    Element.rgb255 108 173 104


warning : Color
warning =
    Element.rgb255 233 157 48


danger : Color
danger =
    Element.rgb255 244 67 54


shadeLight : Color
shadeLight =
    Element.rgb255 248 249 249


shadeDark : Color
shadeDark =
    Element.rgb255 73 61 67


accentLight : Color
accentLight =
    Element.rgb255 242 126 49


accentDark : Color
accentDark =
    Element.rgb255 86 87 68
