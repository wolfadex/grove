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
    | NewSetup SetupModel
    | ProjectList SharedModel
    | Settings SharedModel
    | NewProject SharedModel NewProjectBuilder


type alias SetupModel =
    { name : String
    , email : String
    }


type alias SharedModel =
    { projects : Dict Id Project
    , rootPath : String
    , name : String
    , email : String
    , editor : Editor
    , activeProject : Id
    }


baseSharedModel : { a | name : String, email : String } -> SharedModel
baseSharedModel { name, email } =
    { projects = Dict.empty
    , rootPath = ""
    , name = name
    , email = email
    , editor = NoEditor
    , activeProject = ""
    }


type NewProjectBuilder
    = Building NewProjectModel (Maybe String)
    | Creating NewProjectModel


type alias NewProjectModel =
    { name : String }


encodeNewProject : SharedModel -> NewProjectModel -> Value
encodeNewProject model { name } =
    Json.Encode.object
        [ ( "name", Json.Encode.string name )
        , ( "rootPath", Json.Encode.string model.rootPath )
        , ( "userName", Json.Encode.string model.name )
        , ( "userEmail", Json.Encode.string model.email )
        ]


parseNewProject : NewProjectModel -> Result String NewProjectModel
parseNewProject ({ name } as project) =
    if String.isEmpty name then
        Err "A project requires a name"

    else
        Ok project


baseNewProjectModel : NewProjectBuilder
baseNewProjectModel =
    Building
        { name = "" }
        Nothing


type alias Id =
    String


type alias Project =
    { path : String
    , localName : String
    , name : String
    , icon : Icon
    , dependencies : { direct : Dict Name Dependency, indirect : Dict Name Dependency }
    }


type alias Name =
    String


type alias Dependency =
    { version : Version
    }


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
    | ImageIcon String


type Editor
    = NoEditor
    | VSCode
    | Atom
    | SublimeText


decodeEditor : Decoder Editor
decodeEditor =
    Json.Decode.string
        |> Json.Decode.andThen
            (\str ->
                Json.Decode.succeed <|
                    case str of
                        "vscode" ->
                            VSCode

                        "atom" ->
                            Atom

                        "sublimetext" ->
                            SublimeText

                        _ ->
                            NoEditor
            )


encodeEditor : Editor -> Value
encodeEditor editor =
    Json.Encode.string <|
        case editor of
            NoEditor ->
                "none"

            VSCode ->
                "vscode"

            Atom ->
                "atom"

            SublimeText ->
                "sublimetext"


editorStartupCommand : Editor -> Maybe String
editorStartupCommand editor =
    case editor of
        NoEditor ->
            Nothing

        VSCode ->
            Just "code"

        Atom ->
            Just "atom"

        SublimeText ->
            Just "subl"


editorName : Editor -> String
editorName editor =
    case editor of
        NoEditor ->
            "No Editor"

        VSCode ->
            "Visual Studio Code"

        Atom ->
            "Atom"

        SublimeText ->
            "Sublime Text"


editorUrl : Editor -> String
editorUrl editor =
    case editor of
        NoEditor ->
            ""

        VSCode ->
            "https://code.visualstudio.com/"

        Atom ->
            "https://atom.io/"

        SublimeText ->
            "https://www.sublimetext.com/"


type Msg
    = MainStarted Value
    | SetName String
    | SetEmail String
    | GetRootDirectory
    | SetRootPath String
    | LoadProjects Value
    | ShowSettings
    | HideSettings
    | ShowNewProjectForm
    | HideNewProjectForm
    | SetNewProjectName String
    | CreateNewProject
    | ProjectCreated String
    | EditorSelected Editor
    | Develop Id
    | DeleteProject Id String
    | DownloadEditor String
    | SetActiveProject Id



---- INIT ----


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading
    , Cmd.none
    )



---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ mainStarted MainStarted
        , setRootPath SetRootPath
        , loadProjects LoadProjects
        , projectCreated ProjectCreated
        ]



---- PORTS ----
-- INCOMING


port mainStarted : (Value -> msg) -> Sub msg


port setRootPath : (String -> msg) -> Sub msg


port loadProjects : (Value -> msg) -> Sub msg


port projectCreated : (String -> msg) -> Sub msg



-- OUTGOING


port getRootPath : () -> Cmd msg


port saveRoot : String -> Cmd msg


port createProject : Value -> Cmd msg


port setName : String -> Cmd msg


port setEmail : String -> Cmd msg


port saveEditor : Value -> Cmd msg


port developProject : ( Maybe String, Id ) -> Cmd msg


port confirmDelete : ( Id, String, String ) -> Cmd msg


port downloadEditor : String -> Cmd msg



---- UPDATE ----


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( DownloadEditor url, _ ) ->
            ( model, downloadEditor url )

        ( MainStarted startupConfig, Loading ) ->
            case Json.Decode.decodeValue decodeStartup startupConfig of
                Ok data ->
                    ( ProjectList data, Cmd.none )

                Err err ->
                    Debug.log (Json.Decode.errorToString err) ( NewSetup { name = "", email = "" }, Cmd.none )

        ( SetName name, NewSetup data ) ->
            ( NewSetup { data | name = name }, Cmd.none )

        ( SetEmail email, NewSetup data ) ->
            ( NewSetup { data | email = email }, Cmd.none )

        ( GetRootDirectory, NewSetup { name, email } ) ->
            ( model, Cmd.batch [ getRootPath (), setName name, setEmail email ] )

        ( GetRootDirectory, _ ) ->
            ( model, getRootPath () )

        ( SetRootPath newRootPath, NewSetup setupData ) ->
            let
                base =
                    baseSharedModel setupData
            in
            ( ProjectList { base | rootPath = newRootPath }
            , saveRoot newRootPath
            )

        ( SetRootPath newRootPath, ProjectList sharedData ) ->
            ( ProjectList { sharedData | rootPath = newRootPath }
            , saveRoot newRootPath
            )

        ( SetRootPath newRootPath, NewProject sharedData newProject ) ->
            ( NewProject { sharedData | rootPath = newRootPath } newProject
            , saveRoot newRootPath
            )

        ( SetRootPath newRootPath, Settings sharedData ) ->
            ( Settings { sharedData | rootPath = newRootPath }
            , saveRoot newRootPath
            )

        ( LoadProjects maybeProjects, ProjectList sharedData ) ->
            case Json.Decode.decodeValue decodeProjects maybeProjects of
                Ok projects ->
                    ( ProjectList { sharedData | projects = projects }, Cmd.none )

                Err err ->
                    Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)

        ( LoadProjects maybeProjects, Settings sharedData ) ->
            case Json.Decode.decodeValue decodeProjects maybeProjects of
                Ok projects ->
                    ( Settings { sharedData | projects = projects }, Cmd.none )

                Err err ->
                    Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)

        ( LoadProjects maybeProjects, NewProject sharedData newProject ) ->
            case Json.Decode.decodeValue decodeProjects maybeProjects of
                Ok projects ->
                    ( NewProject { sharedData | projects = projects } newProject, Cmd.none )

                Err err ->
                    Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)

        ( ShowSettings, ProjectList sharedData ) ->
            ( Settings sharedData, Cmd.none )

        ( HideSettings, Settings sharedData ) ->
            ( ProjectList sharedData, Cmd.none )

        ( ShowNewProjectForm, ProjectList sharedData ) ->
            ( NewProject sharedData baseNewProjectModel, Cmd.none )

        ( HideNewProjectForm, NewProject sharedData _ ) ->
            ( ProjectList sharedData, Cmd.none )

        ( SetNewProjectName name, NewProject sharedData newProject ) ->
            case newProject of
                Building data error ->
                    ( NewProject sharedData (Building { data | name = name } error), Cmd.none )

                Creating _ ->
                    ( model, Cmd.none )

        ( CreateNewProject, NewProject sharedData (Building data _) ) ->
            case parseNewProject data of
                Ok project ->
                    ( NewProject sharedData (Creating data)
                    , project
                        |> encodeNewProject sharedData
                        |> createProject
                    )

                Err err ->
                    ( NewProject sharedData (Building data (Just err)), Cmd.none )

        ( ProjectCreated name, NewProject sharedData (Creating data) ) ->
            if name == data.name then
                ( ProjectList sharedData, Cmd.none )

            else
                ( model, Cmd.none )

        ( EditorSelected editor, Settings sharedData ) ->
            ( Settings { sharedData | editor = editor }
            , editor
                |> encodeEditor
                |> saveEditor
            )

        ( EditorSelected editor, ProjectList sharedData ) ->
            ( ProjectList { sharedData | editor = editor }
            , editor
                |> encodeEditor
                |> saveEditor
            )

        ( EditorSelected editor, NewProject sharedData newProject ) ->
            ( NewProject { sharedData | editor = editor } newProject
            , editor
                |> encodeEditor
                |> saveEditor
            )

        ( Develop id, ProjectList sharedData ) ->
            ( model, developProject ( editorStartupCommand sharedData.editor, id ) )

        ( DeleteProject id name, ProjectList sharedData ) ->
            ( model, confirmDelete ( id, name, sharedData.rootPath ) )

        ( SetActiveProject id, ProjectList sharedData ) ->
            ( ProjectList { sharedData | activeProject = id }, Cmd.none )

        _ ->
            ( model, Cmd.none )


decodeStartup : Decoder SharedModel
decodeStartup =
    Json.Decode.map6
        (\projects rootPath name email maybeEditor activeProject ->
            { projects = projects
            , rootPath = rootPath
            , name = name
            , email = email
            , editor = Maybe.withDefault NoEditor maybeEditor
            , activeProject = activeProject
            }
        )
        (Json.Decode.field "projects" decodeProjects)
        (Json.Decode.field "rootPath" Json.Decode.string)
        (Json.Decode.field "userName" Json.Decode.string)
        (Json.Decode.field "userEmail" Json.Decode.string)
        (Json.Decode.maybe (Json.Decode.field "editor" decodeEditor))
        (Json.Decode.succeed "")


decodeProjects : Decoder (Dict Id Project)
decodeProjects =
    Json.Decode.dict decodeProject


decodeProject : Decoder Project
decodeProject =
    Json.Decode.map5 Project
        (Json.Decode.field "projectPath" Json.Decode.string)
        (Json.Decode.field "directoryName" Json.Decode.string)
        (Json.Decode.field "projectName" Json.Decode.string)
        (Json.Decode.field "icon" decodeIcon)
        (Json.Decode.field "dependencies" decodeDependencies)


decodeDependencies : Decoder { direct : Dict Name Dependency, indirect : Dict Name Dependency }
decodeDependencies =
    Json.Decode.map2
        (\direct indirect ->
            { direct = direct
            , indirect = indirect
            }
        )
        (Json.Decode.field "direct" decodeDependecyDict)
        (Json.Decode.field "indirect" decodeDependecyDict)


decodeDependecyDict : Decoder (Dict Name Dependency)
decodeDependecyDict =
    Json.Decode.dict decodeVersion
        |> Json.Decode.andThen
            (Dict.map
                (\_ version ->
                    { version = version }
                )
                >> Json.Decode.succeed
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
                    "image" ->
                        decodeImageIcon

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


decodeImageIcon : Decoder Icon
decodeImageIcon =
    Json.Decode.field "uri" Json.Decode.string
        |> Json.Decode.andThen (ImageIcon >> Json.Decode.succeed)



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

            NewSetup data ->
                viewNewSetup data

            ProjectList data ->
                viewProjectList data

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


viewNewSetup : SetupModel -> Element Msg
viewNewSetup { name, email } =
    Element.column
        [ Element.centerX
        , Element.centerY
        , Element.spacing 8
        , Element.width (Element.fill |> Element.maximum 500)
        ]
        [ Ui.customStyles
        , Element.el
            [ Element.centerX, Font.size 32, Element.padding 16 ]
            (Element.text "Welcome to Grove!")
        , Element.paragraph
            [ Element.centerX, Ui.whiteSpacePre ]
            [ Element.text "It looks like this is your first time using Grove. I'm going to need some information for creeating new projects. None of it is shared outside of this app." ]
        , Ui.text
            []
            { onChange = SetName
            , value = name
            , label = Element.text "First I need your name"
            }
        , if String.isEmpty name then
            Element.none

          else
            Ui.text
                []
                { onChange = SetEmail
                , value = email
                , label = Element.text "then your Email"
                }
        , if String.isEmpty name || String.isEmpty email then
            Element.none

          else
            Element.column
                [ Element.spacing 8 ]
                [ Element.text "Finally, you need to"
                , Ui.button
                    [ Element.centerX ]
                    { onPress = GetRootDirectory
                    , label = Element.text "Set Your Root Directory"
                    }
                ]
        ]


viewProjectList : SharedModel -> Element Msg
viewProjectList { projects, editor, activeProject } =
    Element.row
        [ Element.height Element.fill
        , Element.width Element.fill
        ]
        [ Element.column
            [ Background.color Color.primary
            , Element.padding 8
            , Element.spacing 16
            , Element.height Element.fill
            ]
            [ Ui.button
                [ Element.centerX ]
                { onPress = ShowNewProjectForm
                , label = Element.text "+"
                }
            , Keyed.column
                [ Element.spacing 8
                , Element.centerX
                ]
                (projects
                    |> Dict.toList
                    |> List.map (viewProjectButton activeProject)
                )
            , Ui.button
                [ Element.alignBottom ]
                { onPress = ShowSettings
                , label = Element.text "Settings"
                }
            ]
        , viewProjectDetails editor activeProject (Dict.get activeProject projects)
        ]


viewProjectDetails : Editor -> Id -> Maybe Project -> Element Msg
viewProjectDetails editor id maybeProject =
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

            Just { localName, dependencies } ->
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
                            (case editor of
                                NoEditor ->
                                    { onPress = ShowSettings
                                    , label = Element.text "Set Editor"
                                    }

                                _ ->
                                    { onPress = Develop id
                                    , label = Element.text "Develop"
                                    }
                            )
                        , Ui.button
                            [ Background.color Color.accentLight ]
                            { onPress = SetActiveProject id
                            , label = Element.text "Test"
                            }
                        , Ui.button
                            [ Background.color Color.accentLight ]
                            { onPress = SetActiveProject id
                            , label = Element.text "Build"
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
                                { onPress = SetActiveProject id
                                , label = Element.text "Add"
                                }
                            ]
                        , Element.column
                            [ Element.spacing 8
                            ]
                            (dependencies.direct
                                |> Dict.toList
                                |> List.map viewDependency
                            )
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


viewDependency : ( Name, Dependency ) -> Element Msg
viewDependency ( name, { version } ) =
    Element.el
        [ Element.paddingXY 8 0 ]
        (Element.text (name ++ ": " ++ stringFromVersion version))


viewSettings : SharedModel -> Element Msg
viewSettings { rootPath, name, email, editor } =
    Element.column
        [ Background.color Color.primary
        , Element.spacing 16
        , Element.padding 16
        , Element.centerX
        , Element.centerY
        , Border.rounded 3
        ]
        [ Element.text ("Name: " ++ name)
        , Element.text ("Email: " ++ email)
        , Element.paragraph
            [ Ui.whiteSpacePre ]
            [ Element.text "Root Path: "
            , Element.text rootPath
            ]
        , Ui.button
            []
            { onPress = GetRootDirectory
            , label = Element.text "Change Root"
            }
        , Input.radio
            []
            { onChange = EditorSelected
            , selected =
                case editor of
                    NoEditor ->
                        Nothing

                    editorSelected ->
                        Just editorSelected
            , label = Input.labelAbove [] (Element.text "Editor:")
            , options =
                List.map
                    (\ed ->
                        Input.option
                            ed
                            (Element.row
                                [ Element.spacing 8
                                , Element.padding 8
                                ]
                                [ Input.button
                                    [ Font.underline ]
                                    { onPress = Just (DownloadEditor (editorUrl ed))
                                    , label = Element.text "Download"
                                    }
                                , Element.text (editorName ed)
                                ]
                            )
                    )
                    editorOptions
            }
        , Ui.button
            [ Element.alignBottom
            , Element.alignRight
            ]
            { onPress = HideSettings
            , label = Element.text "Back"
            }
        ]


editorOptions : List Editor
editorOptions =
    [ VSCode, Atom, SublimeText ]


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
        { onPress = Just (SetActiveProject id)
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

                ImageIcon _ ->
                    Debug.todo "handle custom icon"
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
            { onChange = SetNewProjectName
            , label = Element.text "Name"
            , value = projectData.name
            }
        , case error of
            Nothing ->
                Element.none

            Just err ->
                Element.text err
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
