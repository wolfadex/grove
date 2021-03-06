port module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Keyed as Keyed
import Filesize
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


type alias Model =
    { projects : Loadable (Dict Id Project)
    , state : State
    }


type State
    = ProjectList String
    | ProjectDetails Id
    | Settings
    | NewProject NewProjectBuilder


type Loadable d
    = Loading
    | Success d
    | Failure String


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
    , dependencies : Dict Name Dependency
    , building : Bool
    , devServerRunning : Bool
    , bundle : Maybe Bundle
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


type Bundle
    = Bundle
        { label : String
        , path : String
        , children : List Bundle
        , size : Int
        , time : Int
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
    | StopServer Id
    | SetProjectFilter String
    | DeleteProject Id String
    | ViewProjectDetails Id
    | ViewProjectList
    | Eject Id
    | BuildProject Id
    | FromMain Value



---- INIT ----


init : () -> ( Model, Cmd Msg )
init _ =
    ( { projects = Loading
      , state = ProjectList ""
      }
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
    case msg of
        ShowSettings ->
            ( model, Cmd.none )

        HideSettings ->
            ( model, Cmd.none )

        ViewProjectList ->
            ( { model | state = ProjectList "" }, Cmd.none )

        SetProjectFilter filter ->
            case model.state of
                ProjectList _ ->
                    ( { model | state = ProjectList filter }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ShowNewProjectForm ->
            case model.state of
                ProjectList _ ->
                    ( { model | state = NewProject baseNewProjectModel }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        HideNewProjectForm ->
            case model.state of
                NewProject _ ->
                    ( { model | state = ProjectList "" }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetNewProjectName name ->
            case model.state of
                NewProject (Building data error) ->
                    ( { model | state = NewProject (Building { data | name = name } error) }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetNewProjectAuthor author ->
            case model.state of
                NewProject (Building data error) ->
                    ( { model | state = NewProject (Building { data | author = author } error) }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetNewProjectElmProgram elmProgram ->
            case model.state of
                NewProject (Building data error) ->
                    ( { model | state = NewProject (Building { data | elmProgram = elmProgram } error) }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        CreateNewProject ->
            case model.state of
                NewProject (Building data _) ->
                    case parseNewProject data of
                        Ok project ->
                            ( { model | state = NewProject (Creating data) }
                            , project
                                |> encodeNewProject
                                |> toMain "CREATE_PROJECT"
                            )

                        Err err ->
                            ( { model | state = NewProject (Building data (Just err)) }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Develop id ->
            ( model
            , toMain
                "DEVELOP_PROJECT"
                (Json.Encode.object
                    [ ( "projectPath", Json.Encode.string id )
                    ]
                )
            )

        StopServer id ->
            ( model
            , toMain
                "STOP_DEV_SERVER"
                (Json.Encode.object
                    [ ( "projectPath", Json.Encode.string id )
                    ]
                )
            )

        DeleteProject id name ->
            ( model
            , toMain
                "CONFIRM_DELETE"
                (Json.Encode.object
                    [ ( "projectPath", Json.Encode.string id )
                    , ( "name", Json.Encode.string name )
                    ]
                )
            )

        ViewProjectDetails id ->
            case model.state of
                ProjectList _ ->
                    ( { model | state = ProjectDetails id }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Eject id ->
            ( model, toMain "EJECT_PROJECT" (Json.Encode.string id) )

        BuildProject id ->
            ( { model | projects = updateProjects id (Maybe.map (\p -> { p | building = True })) model.projects }
            , toMain "BUILD_PROJECT" (Json.Encode.string id)
            )

        FromMain value ->
            case Json.Decode.decodeValue decodeMainMessage value of
                Err err ->
                    ( model, Cmd.none )

                Ok { action, payload } ->
                    case action of
                        -- ( "MAIN_STARTED", Loading ) ->
                        --     case Json.Decode.decodeValue decodeStartup payload of
                        --         Ok data ->
                        --             ( ProjectList data "", Cmd.none )
                        --         Err _ ->
                        --             ( ProjectList
                        --                 { projects = Dict.empty
                        --                 , activeProject = ""
                        --                 }
                        --                 ""
                        --             , Cmd.none
                        --             )
                        "LOAD_PROJECTS" ->
                            case Json.Decode.decodeValue decodeProjects payload of
                                Ok projects ->
                                    ( { model | projects = Success projects }, Cmd.none )

                                Err err ->
                                    Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)

                        --( model, Cmd.none )
                        "LOAD_PROJECT" ->
                            case Json.Decode.decodeValue decodeProjects payload of
                                Ok project ->
                                    ( { model
                                        | projects =
                                            case model.projects of
                                                Loading ->
                                                    Loading

                                                Failure _ ->
                                                    Success project

                                                Success projects ->
                                                    Success (Dict.union project projects)
                                        , state =
                                            case project |> Dict.toList |> List.head |> Maybe.map Tuple.first of
                                                Just id ->
                                                    ProjectDetails id

                                                Nothing ->
                                                    model.state
                                      }
                                    , Cmd.none
                                    )

                                Err err ->
                                    -- Debug.todo ("Handle error: " ++ Json.Decode.errorToString err)
                                    ( model, Cmd.none )

                        "PROJECT_CREATED" ->
                            case ( Json.Decode.decodeValue Json.Decode.string payload, model.state ) of
                                ( Ok name, NewProject (Creating data) ) ->
                                    if name == data.name then
                                        ( { model | state = ProjectList "" }, Cmd.none )

                                    else
                                        ( model, Cmd.none )

                                ( Ok _, _ ) ->
                                    ( model, Cmd.none )

                                ( Err err, _ ) ->
                                    Debug.log (Json.Decode.errorToString err) ( model, Cmd.none )

                        "PROJECT_DELETED" ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( { model
                                        | projects =
                                            case model.projects of
                                                Loading ->
                                                    Loading

                                                Failure e ->
                                                    Failure e

                                                Success projects ->
                                                    Success (Dict.remove id projects)
                                      }
                                    , Cmd.none
                                    )

                                Err _ ->
                                    ( model, Cmd.none )

                        "PROJECT_SERVER_STARTED" ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( { model | projects = updateProjects id (Maybe.map (\p -> { p | devServerRunning = True })) model.projects }
                                    , Cmd.none
                                    )

                                Err _ ->
                                    ( model, Cmd.none )

                        "PROJECT_SERVER_STOPPED" ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( { model | projects = updateProjects id (Maybe.map (\p -> { p | devServerRunning = False })) model.projects }
                                    , Cmd.none
                                    )

                                Err _ ->
                                    ( model, Cmd.none )

                        "PROJECT_BUILT" ->
                            case Json.Decode.decodeValue Json.Decode.string payload of
                                Ok id ->
                                    ( { model | projects = updateProjects id (Maybe.map (\p -> { p | building = False })) model.projects }
                                    , Cmd.none
                                    )

                                Err _ ->
                                    ( model, Cmd.none )

                        "PROJECT_BUNDLE" ->
                            case Json.Decode.decodeValue decodeNewBundle payload of
                                Ok ( id, bundle ) ->
                                    let
                                        updatedProjects =
                                            updateProjects id (Maybe.map (\p -> { p | bundle = Just bundle })) model.projects
                                    in
                                    ( { model | projects = updatedProjects }
                                    , case updatedProjects of
                                        Success projects ->
                                            case Dict.get id projects of
                                                Nothing ->
                                                    Cmd.none

                                                Just project ->
                                                    toMain "SAVE_PROJECT_STATE" (encodeProject id project)

                                        _ ->
                                            Cmd.none
                                    )

                                Err err ->
                                    Debug.todo ("Decode bundle error: " ++ Json.Decode.errorToString err)

                        _ ->
                            Debug.todo ("Unhandled message from Main: " ++ action ++ ", " ++ Debug.toString payload)


decodeNewBundle : Decoder ( Id, Bundle )
decodeNewBundle =
    Json.Decode.field "projectPath" Json.Decode.string
        |> Json.Decode.andThen
            (\id ->
                Json.Decode.field "bundle" (decodeBundle id)
                    |> Json.Decode.andThen
                        (\bundle -> Json.Decode.succeed ( id, bundle ))
            )


decodeBundle : Id -> Decoder Bundle
decodeBundle id =
    Json.Decode.map4
        (\name children size time ->
            Bundle
                { label = String.replace (id ++ "/dist/") "" name
                , path = name
                , children = children
                , size = size
                , time = time
                }
        )
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field
            "children"
            (Json.Decode.list
                (Json.Decode.lazy (\_ -> decodeBundle id))
                |> Json.Decode.map (List.filter (\(Bundle { label }) -> not (String.endsWith ".map" label)))
            )
        )
        (Json.Decode.field "totalSize" Json.Decode.int)
        (Json.Decode.field "bundleTime" Json.Decode.int)


encodeBundle : Bundle -> Value
encodeBundle (Bundle { label, path, children, size, time }) =
    Json.Encode.object
        [ ( "label", Json.Encode.string label )
        , ( "name", Json.Encode.string path )
        , ( "totalSize", Json.Encode.int size )
        , ( "bundleTime", Json.Encode.int time )
        , ( "children", Json.Encode.list encodeBundle children )
        ]



-- { label : String
-- , path : String
-- , children : Dict String Bundle
-- , totalSize : Int
-- , bundleTime : Int
-- }


updateProjects : Id -> (Maybe Project -> Maybe Project) -> Loadable (Dict Id Project) -> Loadable (Dict Id Project)
updateProjects id f projects =
    case projects of
        Loading ->
            Loading

        Failure e ->
            Failure e

        Success p ->
            Success (Dict.update id f p)



-- decodeStartup : Decoder SharedModel
-- decodeStartup =
--     Json.Decode.map
--         (\activeProject ->
--             { projects = Dict.empty
--             , activeProject = activeProject
--             }
--         )
--         (Json.Decode.succeed "")


decodeProjects : Decoder (Dict Id Project)
decodeProjects =
    Json.Decode.dict decodeProject


decodeProject : Decoder Project
decodeProject =
    Json.Decode.field "projectPath" Json.Decode.string
        |> Json.Decode.andThen
            (\path ->
                Json.Decode.map5
                    (\localName name author dependencies bundle ->
                        { path = path
                        , localName = localName
                        , name = name
                        , author = author
                        , dependencies = dependencies
                        , building = False
                        , devServerRunning = False
                        , bundle = Debug.log "bundle" bundle
                        }
                    )
                    (Json.Decode.field "directoryName" Json.Decode.string)
                    (Json.Decode.field "projectName" Json.Decode.string)
                    (Json.Decode.field "author" Json.Decode.string)
                    (Json.Decode.field "dependencies" decodeDependencies)
                    (Json.Decode.maybe (Json.Decode.field "bundle" (decodeBundle path)))
            )


encodeProject : Id -> Project -> Value
encodeProject id { bundle } =
    Json.Encode.object
        [ ( "projectPath", Json.Encode.string id )
        , ( "bundle"
          , case bundle of
                Nothing ->
                    Json.Encode.null

                Just b ->
                    encodeBundle b
          )
        ]


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



---- VIEW ----


view : Model -> Html Msg
view model =
    Element.layout
        [ Element.width Element.fill
        , Element.height Element.fill
        , Background.color Color.shadeLight
        ]
        (case model.state of
            ProjectList filter ->
                viewProjectList filter model

            ProjectDetails id ->
                viewProjectDetails id model

            Settings ->
                viewSettings

            NewProject newProject ->
                viewNewProject newProject
        )


viewProjectList : String -> Model -> Element Msg
viewProjectList filter { projects } =
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
                    { onPress = Just ShowNewProjectForm
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
            , case projects of
                Loading ->
                    Element.text "Loading Projects..."

                Failure err ->
                    Element.text ("Failed to load projects: " ++ err)

                Success ps ->
                    Keyed.column
                        [ Element.spacing 8
                        , Element.centerX
                        , Element.width Element.fill
                        , Element.scrollbarY
                        ]
                        (ps
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
            { onPress = Just (Develop id)
            , label = Element.text "Develop"
            }
        , Ui.button
            [ Element.alignRight
            , Background.color Color.danger
            ]
            { onPress = Just (DeleteProject id localName)
            , label = Element.text "Delete"
            }
        ]
    )


viewProjectDetails : Id -> Model -> Element Msg
viewProjectDetails id { projects } =
    case projects of
        Loading ->
            Element.text "Loading Projects..."

        Failure err ->
            Element.text ("Failed to load projects: " ++ err)

        Success prjs ->
            case Dict.get id prjs of
                Nothing ->
                    Element.text "Unable to find this project, try refreshing your project list."

                Just { name, localName, devServerRunning, building, bundle } ->
                    Element.column
                        [ Element.width Element.fill
                        , Element.height Element.fill
                        ]
                        [ Element.row
                            [ Background.color Color.primary
                            , Element.padding 16
                            , Element.spacing 16
                            , Element.width Element.fill
                            ]
                            [ Ui.button
                                []
                                { onPress = Just ViewProjectList
                                , label = Element.text "Back"
                                }
                            , Element.text (name ++ " Dashboard")
                            ]
                        , Element.row
                            [ Element.spacing 16
                            , Element.padding 16
                            ]
                            [ Ui.button
                                [ Element.alignRight ]
                                { onPress = Just (Develop id)
                                , label = Element.text "Develop"
                                }
                            , Ui.button
                                [ Background.color Color.accentLight ]
                                { onPress = Just (ViewProjectDetails id)
                                , label = Element.text "Test"
                                }
                            , Ui.button
                                [ Background.color Color.accentLight ]
                                { onPress =
                                    if building then
                                        Nothing

                                    else
                                        Just (BuildProject id)
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
                                { onPress = Just (Eject id)
                                , label = Element.text "Eject"
                                }
                            , Ui.button
                                [ Element.alignRight
                                , Background.color Color.danger
                                ]
                                { onPress = Just (DeleteProject id localName)
                                , label = Element.text "Delete"
                                }
                            ]
                        , if devServerRunning then
                            Element.row
                                [ Element.spacing 4
                                , Element.padding 16
                                ]
                                [ Element.text "Develpment server running: "
                                , Ui.button
                                    [ Element.alignRight ]
                                    { onPress = Just (StopServer id)
                                    , label = Element.text "Stop"
                                    }
                                ]

                          else
                            Element.none
                        , case bundle of
                            Nothing ->
                                Element.none

                            Just root ->
                                Element.column
                                    [ Element.width (Element.px 600)
                                    , Element.padding 16
                                    ]
                                    [ Element.text "Production Build Size:"
                                    , Element.row
                                        [ Element.width Element.fill
                                        ]
                                        [ icicle
                                            { root = root
                                            , label =
                                                \(Bundle { label, size }) ->
                                                    Element.row
                                                        [ Element.padding 8
                                                        , Element.width Element.fill
                                                        ]
                                                        [ Element.text label, Element.el [ Element.alignRight ] (Element.text (Filesize.format size)) ]
                                            , parentSize = totalWithChildren root
                                            , size = totalWithChildren
                                            , percent = \parentSize b -> totalWithChildren b * 100 // parentSize
                                            , children = \(Bundle { children }) -> children
                                            }
                                        ]
                                    ]
                        ]


icicle : { root : a, label : a -> Element Msg, parentSize : Int, size : a -> Int, percent : Int -> a -> Int, children : a -> List a } -> Element Msg
icicle ({ root, label, parentSize, size, percent, children } as base) =
    let
        fillPercent =
            percent parentSize root
    in
    Element.column
        [ Element.width (Element.fillPortion fillPercent), Element.alignTop ]
        [ Element.el
            [ Element.width Element.fill
            , Element.height (Element.fill |> Element.minimum 10)
            , Background.color (Element.rgba255 0 196 255 0.5)
            , Border.solid
            , Border.width 1
            , Element.padding 4
            ]
            (label root)
        , Element.row
            [ Element.width Element.fill ]
            (List.map
                (\item ->
                    icicle { base | root = item, parentSize = size item }
                )
                (children root)
            )
        ]


totalWithChildren : Bundle -> Int
totalWithChildren (Bundle { size, children }) =
    List.foldl (\child total -> totalWithChildren child + total) size children


viewSettings : Element Msg
viewSettings =
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
            { onPress = Just HideSettings
            , label = Element.text "Back"
            }
        ]


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
                { onPress = Just HideNewProjectForm
                , label = Element.text "Cancel"
                }
            , Ui.button
                [ Background.color Color.success ]
                { onPress = Just CreateNewProject
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
