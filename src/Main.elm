port module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html exposing (Html)
import Json.Decode exposing (Decoder, Value)
import Ui
import Ui.Color as Color


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }



---- TYPES ----


type Model
    = NewSetup
    | ExistingSetup ExistingModel


type alias ExistingModel =
    { menu : Collapsible
    , projects : Dict Id Project
    , rootPath : String
    }


type alias Id =
    String


type alias Project =
    { path : String
    , localName : String
    , name : String
    }


type Collapsible
    = Expanded
    | Collapsed


type Msg
    = MainStarted Value
    | GetRootDirectory
    | SetRootPath String
    | LoadProjects Value



---- INIT ----


init : () -> ( Model, Cmd Msg )
init _ =
    ( NewSetup
    , Cmd.none
    )



---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ mainStarted MainStarted
        , setRootPath SetRootPath
        , loadProjects LoadProjects
        ]



---- PORTS ----
-- INCOMING


port mainStarted : (Value -> msg) -> Sub msg


port setRootPath : (String -> msg) -> Sub msg


port loadProjects : (Value -> msg) -> Sub msg



-- OUTGOING


port getRootPath : () -> Cmd msg


port saveRoot : String -> Cmd msg



---- UPDATE ----


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( MainStarted startupConfig, NewSetup ) ->
            case Json.Decode.decodeValue decodeStartup startupConfig of
                Ok data ->
                    ( ExistingSetup data, Cmd.none )

                Err err ->
                    Debug.todo ("Handle startup error: " ++ Json.Decode.errorToString err)

        ( GetRootDirectory, _ ) ->
            ( model, getRootPath () )

        ( SetRootPath newRootPath, NewSetup ) ->
            ( ExistingSetup { menu = Expanded, projects = Dict.empty, rootPath = newRootPath }
            , saveRoot newRootPath
            )

        ( SetRootPath newRootPath, ExistingSetup data ) ->
            ( ExistingSetup { data | rootPath = newRootPath }
            , saveRoot newRootPath
            )

        ( LoadProjects maybeProjects, ExistingSetup data ) ->
            case Json.Decode.decodeValue decodeProjects maybeProjects of
                Ok projects ->
                    ( ExistingSetup { data | projects = projects }, Cmd.none )

                Err err ->
                    Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)

        _ ->
            ( model, Cmd.none )


decodeStartup : Decoder ExistingModel
decodeStartup =
    Json.Decode.map3 ExistingModel
        (Json.Decode.succeed Expanded)
        (Json.Decode.field "projects" decodeProjects)
        (Json.Decode.field "rootPath" Json.Decode.string)


decodeProjects : Decoder (Dict Id Project)
decodeProjects =
    Json.Decode.dict decodeProject


decodeProject : Decoder Project
decodeProject =
    Json.Decode.map3 Project
        (Json.Decode.field "projectPath" Json.Decode.string)
        (Json.Decode.field "direectoryName" Json.Decode.string)
        (Json.Decode.field "projectName" Json.Decode.string)



---- VIEW ----


view : Model -> Html Msg
view model =
    Element.layout
        [ Element.width Element.fill
        , Element.height Element.fill
        , Background.color Color.white
        ]
        (case model of
            NewSetup ->
                viewNewSetup

            ExistingSetup data ->
                viewExistingSetup data
        )


viewNewSetup : Element Msg
viewNewSetup =
    Element.column
        [ Element.centerX
        , Element.centerY
        , Element.spacing 32
        ]
        [ Ui.customStyles
        , Element.el
            [ Element.centerX, Font.size 32 ]
            (Element.text "Welcome to Grove!")
        , Element.paragraph
            [ Element.centerX, Ui.whiteSpacePre ]
            [ Element.text "It looks like this is your first time using Grove.\nFirst things first, please"
            ]
        , Ui.button
            [ Element.centerX ]
            { onPress = Just GetRootDirectory
            , label = Element.text "Set Your Root Directory"
            }
        ]


viewExistingSetup : ExistingModel -> Element Msg
viewExistingSetup model =
    Element.row
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
        [ Ui.customStyles
        , Element.column
            [ Element.height Element.fill
            , Background.color (Element.rgb 0.4 0.8 0.4)
            ]
            [ Element.text "options" ]
        , Element.column
            []
            [ Element.text "body" ]
        ]
