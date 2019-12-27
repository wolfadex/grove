port module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Keyed as Keyed
import Html exposing (Html)
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
    }


baseSharedModel : { a | name : String, email : String } -> SharedModel
baseSharedModel { name, email } =
    { projects = Dict.empty
    , rootPath = ""
    , name = name
    , email = email
    , editor = NoEditor
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
    }


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

        _ ->
            ( model, Cmd.none )


decodeStartup : Decoder SharedModel
decodeStartup =
    Json.Decode.map5
        (\projects rootPath name email maybeEditor ->
            { projects = projects
            , rootPath = rootPath
            , name = name
            , email = email
            , editor = Maybe.withDefault NoEditor maybeEditor
            }
        )
        (Json.Decode.field "projects" decodeProjects)
        (Json.Decode.field "rootPath" Json.Decode.string)
        (Json.Decode.field "userName" Json.Decode.string)
        (Json.Decode.field "userEmail" Json.Decode.string)
        (Json.Decode.maybe (Json.Decode.field "editor" decodeEditor))


decodeProjects : Decoder (Dict Id Project)
decodeProjects =
    Json.Decode.dict decodeProject


decodeProject : Decoder Project
decodeProject =
    Json.Decode.map3 Project
        (Json.Decode.field "projectPath" Json.Decode.string)
        (Json.Decode.field "directoryName" Json.Decode.string)
        (Json.Decode.field "projectName" Json.Decode.string)



---- VIEW ----


view : Model -> Html Msg
view model =
    Element.layout
        [ Element.width Element.fill
        , Element.height Element.fill
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
viewProjectList { projects, editor } =
    Element.column
        [ Element.width Element.fill
        , Element.height Element.fill
        , Element.spacing 16
        ]
        [ Ui.button
            [ Element.alignRight ]
            { onPress = ShowSettings
            , label = Element.text "Settings"
            }
        , Element.column
            [ Element.centerX
            , Background.color Color.secondary1
            , Element.padding 16
            , Element.spacing 16
            , Element.width (Element.shrink |> Element.minimum 800)
            ]
            [ Ui.button
                [ Element.centerX ]
                { onPress = ShowNewProjectForm
                , label = Element.text "New Project"
                }
            , Keyed.column
                [ Element.spacing 8
                , Element.width Element.fill
                ]
                (projects
                    |> Dict.toList
                    |> List.map (viewProject editor)
                )
            ]
        ]


viewSettings : SharedModel -> Element Msg
viewSettings { rootPath, name, email, editor } =
    Element.column
        [ Element.height Element.fill
        , Background.color Color.secondary1
        , Element.spacing 16
        , Element.padding 16
        , Element.centerX
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


viewProject : Editor -> ( Id, Project ) -> ( String, Element Msg )
viewProject editor ( id, { localName } ) =
    ( id
    , Element.row
        [ Element.width Element.fill
        , Background.color Color.primary
        , Element.padding 8
        , Element.spacing 16
        , Border.rounded 2
        ]
        [ Element.text localName
        , Ui.button
            []
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

        -- , Ui.button
        --     []
        --     { onPress = Nothing
        --     , label = Element.text "Test"
        --     }
        -- , Ui.button
        --     []
        --     { onPress = Nothing
        --     , label = Element.text "Build"
        --     }
        , Ui.button
            [ Element.alignRight
            , Background.color Color.complement
            ]
            { onPress = DeleteProject id localName
            , label = Element.text "Delete"
            }
        ]
    )


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
        , Background.color Color.secondary1
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
                [ Background.color Color.primary ]
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
