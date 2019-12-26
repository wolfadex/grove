port module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Json.Decode exposing (Decoder, Value)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }



---- TYPES ----


type alias Model =
    { menu : Collapsible
    , projects : Dict Id Project
    }


type alias Id =
    String


type alias Project =
    { name : String }


type Collapsible
    = Expanded
    | Collapsed


type Msg
    = ProjectsLoaded Value



---- INIT ----


init : () -> ( Model, Cmd Msg )
init _ =
    ( { menu = Expanded
      , projects = Dict.empty
      }
    , Cmd.none
    )



---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ loadProjects ProjectsLoaded ]



---- PORTS ----
-- INCOMING


port loadProjects : (Value -> msg) -> Sub msg



-- OUTGOING
---- UPDATE ----


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ProjectsLoaded maybeProjects ->
            ( model, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    Element.layout
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
        (viewBody model)


viewBody : Model -> Element Msg
viewBody model =
    Element.row
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
        [ Element.column
            [ Element.height Element.fill
            , Background.color (Element.rgb 0.4 0.8 0.4)
            ]
            [ Element.text "options" ]
        , Element.column
            []
            [ Element.text "body" ]
        ]
