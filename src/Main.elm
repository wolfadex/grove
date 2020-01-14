port module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Element exposing (Color, Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Keyed as Keyed
import Html exposing (Html)
import Html.Attributes
import Json.Decode exposing (Decoder, Value)
import Json.Encode
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
    = Loading
    | ProjectList SharedModel String
    | Settings SharedModel
    | NewProject SharedModel NewProjectBuilder


type alias SharedModel =
    { projects : Dict Id Project
    , activeProject : Id
    }


type NewProjectBuilder
    = Building NewProjectModel (Maybe String)
    | Creating NewProjectModel


type ElmProgram
    = ElmProgramSandbox
    | ElmProgramElement
    | ElmProgramDocument
    | ElmProgramApplication


encodeElmProgram : ElmProgram -> Value
encodeElmProgram elmProgram =
    Json.Encode.string <|
        case elmProgram of
            ElmProgramSandbox ->
                "sandbox"

            ElmProgramElement ->
                "element"

            ElmProgramDocument ->
                "document"

            ElmProgramApplication ->
                "application"


elmProgramToString : ElmProgram -> String
elmProgramToString elmProgram =
    case elmProgram of
        ElmProgramSandbox ->
            "Sandbox"

        ElmProgramElement ->
            "Element"

        ElmProgramDocument ->
            "Document"

        ElmProgramApplication ->
            "Application"


type alias NewProjectModel =
    { name : String
    , author : String
    , elmProgram : ElmProgram
    }


encodeNewProject : NewProjectModel -> Value
encodeNewProject { name, author, elmProgram } =
    Json.Encode.object
        [ ( "name", Json.Encode.string name )
        , ( "author", Json.Encode.string author )
        , ( "elmProgram", encodeElmProgram elmProgram )
        ]


parseNewProject : NewProjectModel -> Result String NewProjectModel
parseNewProject ({ name, author } as project) =
    case parseNewProjectName name of
        Just err ->
            Err err

        Nothing ->
            case parseNewProjectAuthor author of
                Just err ->
                    Err err

                Nothing ->
                    Ok project


parseNewProjectName : String -> Maybe String
parseNewProjectName name =
    case String.toList name of
        [] ->
            Just "A project requires a name"

        '.' :: _ ->
            Just "Name cannot start with a '.'"

        '_' :: _ ->
            Just "Name cannot start with a '_'"

        _ ->
            if String.length name > 214 then
                Just "Name is too long. Max length is 214 characters"

            else if String.any Char.isUpper name then
                Just "Upper case letters are not allowed"

            else if String.any (not << isUrlSafeCharacter) name then
                Just "The only allowed characters are a-z, 0-9, -, ., _, and ~"

            else
                Nothing


parseNewProjectAuthor : String -> Maybe String
parseNewProjectAuthor author =
    case String.toList author of
        [] ->
            Just "A project requires a author"

        '.' :: _ ->
            Just "Name cannot start with a '.'"

        '_' :: _ ->
            Just "Name cannot start with a '_'"

        first :: _ ->
            if Char.isDigit first then
                Just "Author can't start with a number"

            else if String.length author > 214 then
                Just "Author is too long. Max length is 214 characters"

            else if String.any Char.isUpper author then
                Just "Upper case letters are not allowed"

            else if String.any (not << isUrlSafeCharacter) author then
                Just "The only allowed characters are: a-z, 0-9, -, ., _, and ~"

            else
                Nothing


isUrlSafeCharacter : Char -> Bool
isUrlSafeCharacter c =
    Char.isAlphaNum c || c == '-' || c == '_' || c == '.' || c == '~'


baseNewProjectModel : NewProjectBuilder
baseNewProjectModel =
    Building
        { name = ""
        , author = ""
        , elmProgram = ElmProgramSandbox
        }
        Nothing


type alias Id =
    String


type alias Project =
    { path : String
    , localName : String
    , name : String
    , author : String
    , icon : Icon
    , dependencies : Dict Name Dependency
    , building : Bool
    }


type alias Name =
    String


type alias Dependency =
    { version : Version
    , license : String
    , type_ : DependencyType
    }


type DependencyType
    = Direct
    | Indirect


type alias Version =
    { major : Int
    , minor : Int
    , patch : Int
    }


stringFromVersion : Version -> String
stringFromVersion { major, minor, patch } =
    [ String.fromInt major
    , String.fromInt minor
    , String.fromInt patch
    ]
        |> String.join "."


type Icon
    = RandomIcon { angle : Int, color : Color }


type Msg
    = ShowSettings
    | HideSettings
    | ShowNewProjectForm
    | HideNewProjectForm
    | SetNewProjectName String
    | SetNewProjectAuthor String
    | SetNewProjectElmProgram ElmProgram
    | CreateNewProject
    | Develop Id
    | SetProjectFilter String
    | DeleteProject Id String
    | ViewProjectDetails Id
    | Eject Id
    | BuildProject Id
    | FromMain Value



---- INIT ----


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading
    , Cmd.none
    )



---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    mainToClient FromMain



---- PORTS ----
-- INCOMING


port mainToClient : (Value -> msg) -> Sub msg



-- OUTGOING


port clientToMain : Value -> Cmd msg


toMain : String -> Value -> Cmd msg
toMain action payload =
    Json.Encode.object
        [ ( "action", Json.Encode.string action )
        , ( "payload", payload )
        ]
        |> clientToMain


decodeMainMessage : Decoder { action : String, payload : Value }
decodeMainMessage =
    Json.Decode.map2
        (\action payload ->
            { action = action, payload = payload }
        )
        (Json.Decode.field "action" Json.Decode.string)
        (Json.Decode.field "payload" Json.Decode.value)



---- UPDATE ----


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( ShowSettings, ProjectList sharedData _ ) ->
            ( Settings sharedData, Cmd.none )

        ( HideSettings, Settings sharedData ) ->
            ( ProjectList sharedData "", Cmd.none )

        ( SetProjectFilter filter, ProjectList sharedData _ ) ->
            ( ProjectList sharedData filter, Cmd.none )

        ( ShowNewProjectForm, ProjectList sharedData _ ) ->
            ( NewProject sharedData baseNewProjectModel, Cmd.none )

        ( HideNewProjectForm, NewProject sharedData _ ) ->
            ( ProjectList sharedData "", Cmd.none )

        ( SetNewProjectName name, NewProject sharedData newProject ) ->
            case newProject of
                Building data error ->
                    ( NewProject sharedData (Building { data | name = name } error), Cmd.none )

                Creating _ ->
                    ( model, Cmd.none )

        ( SetNewProjectAuthor author, NewProject sharedData newProject ) ->
            case newProject of
                Building data error ->
                    ( NewProject sharedData (Building { data | author = author } error), Cmd.none )

                Creating _ ->
                    ( model, Cmd.none )

        ( SetNewProjectElmProgram elmProgram, NewProject sharedData newProject ) ->
            case newProject of
                Building data error ->
                    ( NewProject sharedData (Building { data | elmProgram = elmProgram } error), Cmd.none )

                Creating _ ->
                    ( model, Cmd.none )

        ( CreateNewProject, NewProject sharedData (Building data _) ) ->
            case parseNewProject data of
                Ok project ->
                    ( NewProject sharedData (Creating data)
                    , project
                        |> encodeNewProject
                        |> toMain "CREATE_PROJECT"
                    )

                Err err ->
                    ( NewProject sharedData (Building data (Just err)), Cmd.none )

        ( Develop id, ProjectList _ _ ) ->
            ( model
            , toMain
                "DEVELOP_PROJECT"
                (Json.Encode.object
                    [ ( "projectPath", Json.Encode.string id )
                    ]
                )
            )

        ( DeleteProject id name, ProjectList _ _ ) ->
            ( model
            , toMain
                "CONFIRM_DELETE"
                (Json.Encode.object
                    [ ( "projectPath", Json.Encode.string id )
                    , ( "name", Json.Encode.string name )
                    ]
                )
            )

        ( ViewProjectDetails id, ProjectList sharedData filter ) ->
            ( ProjectList { sharedData | activeProject = id } filter, Cmd.none )

        ( Eject id, _ ) ->
            ( model, toMain "EJECT_PROJECT" (Json.Encode.string id) )

        ( BuildProject id, ProjectList sharedData filter ) ->
            ( ProjectList { sharedData | projects = Dict.update id (Maybe.map (\p -> { p | building = True })) sharedData.projects } filter
            , toMain "BUILD_PROJECT" (Json.Encode.string id)
            )

        ( BuildProject id, NewProject sharedData newProject ) ->
            ( NewProject
                { sharedData | projects = Dict.update id (Maybe.map (\p -> { p | building = True })) sharedData.projects }
                newProject
            , toMain "BUILD_PROJECT" (Json.Encode.string id)
            )

        ( BuildProject id, Settings sharedData ) ->
            ( Settings { sharedData | projects = Dict.update id (Maybe.map (\p -> { p | building = True })) sharedData.projects }
            , toMain "BUILD_PROJECT" (Json.Encode.string id)
            )

        ( FromMain value, _ ) ->
            case Json.Decode.decodeValue decodeMainMessage value of
                Err err ->
                    ( model, Cmd.none )

                Ok { action, payload } ->
                    case ( action, model ) of
                        ( "MAIN_STARTED", Loading ) ->
                            case Json.Decode.decodeValue decodeStartup payload of
                                Ok data ->
                                    ( ProjectList data "", Cmd.none )

                                Err _ ->
                                    ( ProjectList
                                        { projects = Dict.empty
                                        , activeProject = ""
                                        }
                                        ""
                                    , Cmd.none
                                    )

                        ( "LOAD_PROJECTS", ProjectList sharedData filter ) ->
                            case Json.Decode.decodeValue decodeProjects payload of
                                Ok projects ->
                                    ( ProjectList { sharedData | projects = projects } filter, Cmd.none )

                                Err err ->
                                    -- Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)
                                    ( model, Cmd.none )

                        ( "LOAD_PROJECTS", Settings sharedData ) ->
                            case Json.Decode.decodeValue decodeProjects payload of
                                Ok projects ->
                                    ( Settings { sharedData | projects = projects }, Cmd.none )

                                Err err ->
                                    -- Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)
                                    ( model, Cmd.none )

                        ( "LOAD_PROJECTS", NewProject sharedData newProject ) ->
                            case Json.Decode.decodeValue decodeProjects payload of
                                Ok projects ->
                                    ( NewProject { sharedData | projects = projects } newProject, Cmd.none )

                                Err err ->
                                    -- Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)
                                    ( model, Cmd.none )

                        ( "LOAD_PROJECT", ProjectList sharedData filter ) ->
                            case Json.Decode.decodeValue decodeProjects payload of
                                Ok project ->
                                    ( ProjectList
                                        { sharedData
                                            | projects = Dict.union project sharedData.projects
                                            , activeProject =
                                                case project |> Dict.toList |> List.head |> Maybe.map Tuple.first of
                                                    Just id ->
                                                        id

                                                    Nothing ->
                                                        sharedData.activeProject
                                        }
                                        filter
                                    , Cmd.none
                                    )

                                Err err ->
                                    -- Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)
                                    ( model, Cmd.none )

                        ( "LOAD_PROJECT", Settings sharedData ) ->
                            case Json.Decode.decodeValue decodeProjects payload of
                                Ok project ->
                                    ( Settings
                                        { sharedData
                                            | projects = Dict.union project sharedData.projects
                                            , activeProject =
                                                case project |> Dict.toList |> List.head |> Maybe.map Tuple.first of
                                                    Just id ->
                                                        id

                                                    Nothing ->
                                                        sharedData.activeProject
                                        }
                                    , Cmd.none
                                    )

                                Err err ->
                                    -- Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)
                                    ( model, Cmd.none )

                        ( "LOAD_PROJECT", NewProject sharedData newProject ) ->
                            case Json.Decode.decodeValue decodeProjects payload of
                                Ok project ->
                                    ( NewProject
                                        { sharedData
                                            | projects = Dict.union project sharedData.projects
                                            , activeProject =
                                                case project |> Dict.toList |> List.head |> Maybe.map Tuple.first of
                                                    Just id ->
                                                        id

                                                    Nothing ->
                                                        sharedData.activeProject
                                        }
                                        newProject
                                    , Cmd.none
                                    )

                                Err err ->
                                    -- Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)
                                    ( model, Cmd.none )

                        ( "PROJECT_CREATED", NewProject sharedData (Creating data) ) ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok name ->
                                    if name == data.name then
                                        ( ProjectList sharedData "", Cmd.none )

                                    else
                                        ( model, Cmd.none )

                                Err err ->
                                    Debug.log (Json.Decode.errorToString err) ( model, Cmd.none )

                        ( "PROJECT_DELETED", ProjectList sharedData filter ) ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( ProjectList { sharedData | projects = Dict.remove id sharedData.projects } filter, Cmd.none )

                                Err _ ->
                                    ( model, Cmd.none )

                        ( "PROJECT_DELETED", Settings sharedData ) ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( Settings { sharedData | projects = Dict.remove id sharedData.projects }, Cmd.none )

                                Err _ ->
                                    ( model, Cmd.none )

                        ( "PROJECT_DELETED", NewProject sharedData newProject ) ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( NewProject { sharedData | projects = Dict.remove id sharedData.projects } newProject, Cmd.none )

                                Err _ ->
                                    ( model, Cmd.none )

                        ( "PROJECT_BUILT", ProjectList sharedData filter ) ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( ProjectList { sharedData | projects = Dict.update id (Maybe.map (\p -> { p | building = False })) sharedData.projects } filter
                                    , Cmd.none
                                    )

                                Err _ ->
                                    ( model, Cmd.none )

                        ( "PROJECT_BUILT", NewProject sharedData newProject ) ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( NewProject
                                        { sharedData | projects = Dict.update id (Maybe.map (\p -> { p | building = False })) sharedData.projects }
                                        newProject
                                    , Cmd.none
                                    )

                                Err _ ->
                                    ( model, Cmd.none )

                        ( "PROJECT_BUILT", Settings sharedData ) ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( Settings { sharedData | projects = Dict.update id (Maybe.map (\p -> { p | building = False })) sharedData.projects }
                                    , Cmd.none
                                    )

                                Err _ ->
                                    ( model, Cmd.none )

                        _ ->
                            Debug.todo ("Unhandled message from Main: " ++ action ++ ", " ++ Debug.toString payload)

        _ ->
            ( model, Cmd.none )


decodeStartup : Decoder SharedModel
decodeStartup =
    Json.Decode.map
        (\activeProject ->
            { projects = Dict.empty
            , activeProject = activeProject
            }
        )
        (Json.Decode.succeed "")


decodeProjects : Decoder (Dict Id Project)
decodeProjects =
    Json.Decode.dict decodeProject


decodeProject : Decoder Project
decodeProject =
    Json.Decode.map7 Project
        (Json.Decode.field "projectPath" Json.Decode.string)
        (Json.Decode.field "directoryName" Json.Decode.string)
        (Json.Decode.field "projectName" Json.Decode.string)
        (Json.Decode.field "author" Json.Decode.string)
        (Json.Decode.field "icon" decodeIcon)
        (Json.Decode.field "dependencies" decodeDependencies)
        (Json.Decode.succeed False)


decodeDependencies : Decoder (Dict Name Dependency)
decodeDependencies =
    Json.Decode.dict decodeDependency


decodeDependency : Decoder Dependency
decodeDependency =
    Json.Decode.map3 Dependency
        (Json.Decode.field "version" decodeVersion)
        (Json.Decode.field "license" Json.Decode.string)
        (Json.Decode.field "type" decodeDependencyType)


decodeDependencyType : Decoder DependencyType
decodeDependencyType =
    Json.Decode.string
        |> Json.Decode.andThen
            (\str ->
                case str of
                    "direct" ->
                        Json.Decode.succeed Direct

                    "indirect" ->
                        Json.Decode.succeed Indirect

                    _ ->
                        Json.Decode.fail ("Unknown dependency type: " ++ str)
            )


decodeVersion : Decoder Version
decodeVersion =
    Json.Decode.string
        |> Json.Decode.andThen
            (\str ->
                case String.split "." str of
                    [ major, minor, patch ] ->
                        case ( String.toInt major, String.toInt minor, String.toInt patch ) of
                            ( Just mj, Just mi, Just p ) ->
                                Json.Decode.succeed
                                    { major = mj
                                    , minor = mi
                                    , patch = p
                                    }

                            _ ->
                                Json.Decode.fail "Some part of the version isn't a number"

                    _ ->
                        Json.Decode.fail "The version must be in the format 'Int.Int.Int'"
            )


decodeIcon : Decoder Icon
decodeIcon =
    Json.Decode.field "style" Json.Decode.string
        |> Json.Decode.andThen
            (\style ->
                case style of
                    "random" ->
                        decodeRandomIcon

                    _ ->
                        Json.Decode.fail ("Unknown icon style: " ++ style)
            )


decodeRandomIcon : Decoder Icon
decodeRandomIcon =
    Json.Decode.map2
        (\angle color ->
            RandomIcon
                { angle = angle
                , color = color
                }
        )
        (Json.Decode.field "angle" Json.Decode.int)
        (Json.Decode.field "color" decodeIconColor)


decodeIconColor : Decoder Color
decodeIconColor =
    Json.Decode.map3
        (\red green blue ->
            Element.rgb255 red green blue
        )
        (Json.Decode.field "red" Json.Decode.int)
        (Json.Decode.field "green" Json.Decode.int)
        (Json.Decode.field "blue" Json.Decode.int)



---- VIEW ----


view : Model -> Html Msg
view model =
    Element.layout
        [ Element.width Element.fill
        , Element.height Element.fill
        , Background.color Color.shadeLight
        ]
        (case model of
            Loading ->
                viewLoading

            ProjectList data filter ->
                viewProjectList data filter

            Settings data ->
                viewSettings data

            NewProject _ newProject ->
                viewNewProject newProject
        )


viewLoading : Element msg
viewLoading =
    Element.el
        [ Element.centerX
        , Element.centerY
        ]
        (Element.text "Loading...")


viewProjectList : SharedModel -> String -> Element Msg
viewProjectList { projects } filter =
    Element.column
        [ Element.width Element.fill
        , Element.height Element.fill
        , Element.clipY
        ]
        [ Element.el
            [ Background.color Color.primary
            , Font.size 30
            , Element.centerX
            , Element.padding 16
            , Element.width Element.fill
            , Font.center
            ]
            (Element.text "Elm Projects")
        , Element.column
            [ Element.padding 8
            , Element.spacing 16
            , Element.width Element.fill
            , Element.height Element.fill
            , Element.clipY
            , Element.scrollbarY
            ]
            [ Element.row
                [ Element.centerX
                , Element.spacing 16
                ]
                [ Ui.button
                    [ Element.centerX ]
                    { onPress = ShowNewProjectForm
                    , label = Element.text "Create Project"
                    }
                , Input.text
                    []
                    { onChange = SetProjectFilter
                    , placeholder = Just (Input.placeholder [] (Element.text "Filter"))
                    , label = Input.labelHidden "Project Filter"
                    , text = filter
                    }
                ]
            , Keyed.column
                [ Element.spacing 8
                , Element.centerX
                , Element.width Element.fill
                , Element.scrollbarY
                ]
                (projects
                    |> Dict.toList
                    |> List.filter (\( _, p ) -> p.name |> String.toLower |> String.contains (String.toLower filter))
                    |> List.map viewProjectItem
                )

            -- , Ui.button
            --     [ Element.alignBottom ]
            --     { onPress = ShowSettings
            --     , label = Element.text "Settings"
            --     }
            ]
        ]


viewProjectItem : ( Id, Project ) -> ( String, Element Msg )
viewProjectItem ( id, { name, localName } ) =
    ( id
    , Element.row
        [ Border.color Color.accentLight
        , Border.width 2
        , Border.solid
        , Border.rounded 4
        , Element.padding 8
        , Element.spacing 8
        , Element.width Element.fill
        ]
        [ Ui.buttonPlain
            []
            { onPress = ViewProjectDetails id
            , label = Element.text name
            }
        , Ui.button
            [ Element.alignRight ]
            { onPress = Develop id
            , label = Element.text "Open in Editor"
            }
        , Ui.button
            [ Element.alignRight
            , Background.color Color.danger
            ]
            { onPress = DeleteProject id localName
            , label = Element.text "Delete"
            }
        ]
    )



-- Element.row
--     [ Element.height Element.fill
--     , Element.width Element.fill
--     ]
--     [ Element.column
--         [ Background.color Color.primary
--         , Element.padding 8
--         , Element.spacing 16
--         , Element.height Element.fill
--         ]
--         [ Ui.button
--             [ Element.centerX ]
--             { onPress = ShowNewProjectForm
--             , label = Element.text "+"
--             }
--         , Keyed.column
--             [ Element.spacing 8
--             , Element.centerX
--             ]
--             (projects
--                 |> Dict.toList
--                 |> List.map (viewProjectButton activeProject)
--             )
--         , Ui.button
--             [ Element.alignBottom ]
--             { onPress = ShowSettings
--             , label = Element.text "Settings"
--             }
--         ]
--     , viewProjectDetails activeProject (Dict.get activeProject projects)
--     ]


viewProjectDetails : Id -> Maybe Project -> Element Msg
viewProjectDetails id maybeProject =
    Element.el
        [ Element.height Element.fill
        , Element.width Element.fill
        ]
        (case maybeProject of
            Nothing ->
                Ui.button
                    [ Element.centerX
                    , Element.centerY
                    ]
                    { onPress = ShowNewProjectForm
                    , label = Element.text "Create New Project"
                    }

            Just { localName, dependencies, building } ->
                Element.column
                    [ Element.padding 16
                    , Element.spacing 16
                    , Element.height Element.fill
                    , Element.width Element.fill
                    ]
                    [ Element.el
                        [ Font.size 32
                        , Font.underline
                        ]
                        (Element.text localName)
                    , Element.row
                        [ Element.padding 8
                        , Element.spacing 16
                        , Background.color Color.primary
                        ]
                        [ Ui.button
                            [ Background.color Color.accentLight ]
                            { onPress = Develop id
                            , label = Element.text "Develop"
                            }
                        , Ui.button
                            [ Background.color Color.accentLight ]
                            { onPress = ViewProjectDetails id
                            , label = Element.text "Test"
                            }
                        , Ui.button
                            [ Background.color Color.accentLight ]
                            { onPress =
                                if building then
                                    ViewProjectDetails id

                                else
                                    BuildProject id
                            , label =
                                Element.text
                                    (if building then
                                        "Building..."

                                     else
                                        "Build"
                                    )
                            }
                        , Ui.button
                            [ Background.color Color.warning ]
                            { onPress = Eject id
                            , label = Element.text "Eject"
                            }
                        ]
                    , Element.column
                        [ Background.color Color.primary
                        , Element.spacing 16
                        , Element.padding 8
                        , Font.color Color.shadeLight
                        ]
                        [ Element.row
                            [ Element.spacing 32 ]
                            [ Element.text "Dependencies:"
                            , Ui.button
                                [ Background.color Color.success ]
                                { onPress = ViewProjectDetails id
                                , label = Element.text "Add"
                                }
                            ]
                        , let
                            filteredDependencies =
                                dependencies
                                    |> Dict.toList
                                    |> List.filter (Tuple.second >> .type_ >> (==) Direct)
                          in
                          Element.table
                            []
                            { data = filteredDependencies
                            , columns =
                                [ { header = Element.el [ Element.padding 4 ] (Element.text "Name")
                                  , width = Element.shrink
                                  , view = Tuple.first >> Element.text >> Element.el [ Element.padding 4 ]
                                  }
                                , { header = Element.el [ Element.padding 4 ] (Element.text "Version")
                                  , width = Element.shrink
                                  , view = Tuple.second >> .version >> stringFromVersion >> Element.text >> Element.el [ Element.padding 4 ]
                                  }
                                , { header = Element.el [ Element.padding 4 ] (Element.text "License")
                                  , width = Element.shrink
                                  , view = Tuple.second >> .license >> Element.text >> Element.el [ Element.padding 4 ]
                                  }
                                ]
                            }
                        ]

                    -- Delete button is always last
                    , Ui.button
                        [ Element.alignBottom
                        , Element.alignRight
                        , Background.color Color.danger
                        ]
                        { onPress = DeleteProject id localName
                        , label = Element.text "Delete"
                        }
                    ]
        )


viewSettings : SharedModel -> Element Msg
viewSettings _ =
    Element.column
        [ Background.color Color.primary
        , Element.spacing 16
        , Element.padding 16
        , Element.centerX
        , Element.centerY
        , Border.rounded 3
        ]
        [ Ui.button
            [ Element.alignBottom
            , Element.alignRight
            ]
            { onPress = HideSettings
            , label = Element.text "Back"
            }
        ]


viewProjectButton : Id -> ( Id, Project ) -> ( String, Element Msg )
viewProjectButton activeProjectId ( id, { icon } ) =
    ( id
    , Input.button
        [ Element.height (Element.px 64)
        , Element.width (Element.px 64)
        , Border.rounded 3
        , Element.clip
        , Border.solid
        , Border.color Color.shadeDark
        , if activeProjectId == id then
            Border.width 4

          else
            Border.width 0
        ]
        { onPress = Just (ViewProjectDetails id)
        , label =
            case icon of
                RandomIcon { angle, color } ->
                    Element.html <|
                        Html.div
                            [ Html.Attributes.style "height" "100%"
                            , Html.Attributes.style "width" "100%"
                            , Html.Attributes.style "background-size" "32px 32px"
                            , color
                                |> colorToHtml255String
                                |> Html.Attributes.style "background-color"
                            , Html.Attributes.style "background-image"
                                ("linear-gradient("
                                    ++ String.fromInt (angle * 45)
                                    ++ "deg, rgba(255, 255, 255, .2) 25%, transparent 25%, transparent 50%, rgba(255, 255, 255, .2) 50%, rgba(255, 255, 255, .2) 75%, transparent 75%, transparent)"
                                )
                            ]
                            []
        }
    )


colorToHtml255String : Color -> String
colorToHtml255String =
    Element.toRgb
        >> (\{ red, green, blue, alpha } ->
                "rgba("
                    ++ (red |> floatTo255 |> String.fromInt)
                    ++ ","
                    ++ (green |> floatTo255 |> String.fromInt)
                    ++ ","
                    ++ (blue |> floatTo255 |> String.fromInt)
                    ++ ","
                    ++ String.fromFloat alpha
                    ++ ")"
           )


floatTo255 : Float -> Int
floatTo255 float =
    float
        * 256
        |> floor
        |> min 255
        |> max 0


viewNewProject : NewProjectBuilder -> Element Msg
viewNewProject projectBuilder =
    let
        ( projectData, error, creating ) =
            case projectBuilder of
                Building data err ->
                    ( data, err, False )

                Creating data ->
                    ( data, Nothing, True )
    in
    Element.column
        [ Element.width (Element.fill |> Element.maximum 500)
        , Element.spacing 16
        , Element.padding 16
        , Element.centerX
        , Element.centerY
        , Background.color Color.primary
        ]
        [ Element.el
            [ Border.solid
            , Border.widthEach
                { bottom = 1
                , top = 0
                , left = 0
                , right = 0
                }
            , Element.width Element.fill
            ]
            (Element.text "New Project")
        , Ui.text
            []
            { onChange = SetNewProjectAuthor
            , label = Element.text "Author"
            , value = projectData.author
            }
        , Ui.text
            []
            { onChange = SetNewProjectName
            , label = Element.text "Name"
            , value = projectData.name
            }
        , Input.radio
            []
            { onChange = SetNewProjectElmProgram
            , options = List.map viewElmProgramOption elmProgramOptionsList
            , selected = Just projectData.elmProgram
            , label = Input.labelAbove [] (Element.text "Type of Program:")
            }
        , case error of
            Nothing ->
                Element.none

            Just err ->
                Element.paragraph
                    [ Font.color Color.danger ]
                    [ Element.text err ]
        , Element.row
            [ Element.alignRight
            , Element.spacing 16
            ]
            [ Ui.button
                []
                { onPress = HideNewProjectForm
                , label = Element.text "Cancel"
                }
            , Ui.button
                [ Background.color Color.success ]
                { onPress = CreateNewProject
                , label =
                    Element.text <|
                        if creating then
                            "Creating..."

                        else
                            "Create"
                }
            ]
        ]


viewElmProgramOption : ElmProgram -> Input.Option ElmProgram Msg
viewElmProgramOption elmProgram =
    Input.option elmProgram
        (Element.text <| elmProgramToString elmProgram)


elmProgramOptionsList : List ElmProgram
elmProgramOptionsList =
    [ ElmProgramSandbox
    , ElmProgramElement
    , ElmProgramDocument
    , ElmProgramApplication
    ]
