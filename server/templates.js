module.exports = {
  html,
  packageJson,
  elmSandbox,
  elmElement,
  elmDocument,
  elmApplication,
  elmDocs,
  readme,
  groverc,
};

function html(name) {
  return `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="x-ua-compatible" content="ie=edge" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1, shrink-to-fit=no"
    />
    <title>${name}</title>
  </head>
  <body>
    <noscript>
      JavaScript is required to run this app.
    </noscript>
    <div id="root"></div>
    <script src="index.js"></script>
  </body>
</html>
`;
}

function packageJson(projectName, userName, email, description) {
  return `{
  "name": "${projectName}",
  "description": "${description}",
  "version": "1.0.0",
  "author": {
    "name": "${userName}",
    "email": "${email}"
  },
  "license": "MIT",
  "scripts": {
    "dev": "parcel src/index.html",
    "build": "parcel build src/index.html"
  },
  "devDependencies": {
    "elm": "^0.19.1-3",
    "elm-analyse": "^0.16.5",
    "elm-format": "^0.8.2",
    "elm-test": "^0.19.1-revision2",
    "parcel-bundler": "^1.12.4",
    "prettier": "^1.19.1"
  }
}`;
}

function readme(name) {
  return `# ${name}

${description}

This project was created with [Grove](https://github.com/wolfadex/grove).`;
}

function groverc(name, author) {
  return `{
  "name": "${name}",
  "author": "${author}",
  "tests": {
    "status": null
  }
}`;
}

function elmDocs(name, author, description) {
  return `{
  "name": "${author}/${name}",
  "summary": "${description}",
  "version": "1.0.0",
  "exposed-modules": [
    "Main"
  ]
}`;
}

// Elm Templates

function elmSandbox(name) {
  return `module Main exposing (Model, Msg, init, main, update, view)

import Browser
import Html exposing (Html)


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }


---- TYPES ----


type alias Model =
    {}


type Msg
    = NoOp


---- INIT ----


init : Model
init =
    {}


---- UDPATE ----


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model


---- VIEW ----


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.text "Hello, ${name}!" ]
`;
}

function elmElement(name) {
  return `module Main exposing (Model, Msg, init, main, subscriptions, update, view)

import Browser
import Html exposing (Html)


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
    {}


type Msg
    = NoOp


---- INIT ----


init : () -> ( Model, Cmd Msg )
init _ =
    ( {}, Cmd.none )


---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


---- PORTS ----
-- INCOMING
-- OUTGOING

---- UPDATE ----


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


---- VIEW ----


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.text "Hello, ${name}!" ]
`;
}

function elmDocument(name) {
  return `module Main exposing (Model, Msg, init, main, subscriptions, update, view)

import Browser exposing (Document)
import Html exposing (Html)


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


---- TYPES ----


type alias Model =
    {}


type Msg
    = NoOp


---- INIT ----


init : () -> ( Model, Cmd Msg )
init _ =
    ( {}, Cmd.none )


---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


---- PORTS ----
-- INCOMING
-- OUTGOING

---- UPDATE ----


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


---- VIEW ----


view : Model -> Document Msg
view model =
    { title = "${name}"
    , body =
        [ Html.text "Hello, ${name}!" ]
    }
`;
}

function elmApplication(name) {
  return `module Main exposing (Model, Msg, init, main, subscriptions, update, view)

import Browser exposing (Document)
import Browser.Navigation as Nav
import Html exposing (Html)
import Url


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


---- TYPES ----


type alias Model =
    { key : Nav.Key }


type Msg
    = NoOp
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url


---- INIT ----


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { key = key }
    , Cmd.none
    )


---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


---- PORTS ----
-- INCOMING
-- OUTGOING

---- UPDATE ----


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
              Browser.Internal url ->
                ( model
                , Nav.pushUrl model.key (Url.toString url)
                )
      
              Browser.External href ->
                ( model
                , Nav.load href
                )

        UrlChanged url ->
            ( model, Cmd.none )


---- VIEW ----


view : Model -> Document Msg
view model =
    { title = "${name}"
    , body =
        [ Html.text "Hello, ${name}!" ]
    }
`;
}
