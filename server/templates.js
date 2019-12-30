module.exports = {
  html,
  packageJson,
  elmSandbox,
  elmElement,
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

function packageJson(projectName, userName, email) {
  return `{
  "name": "${projectName}",
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

This project was created with [Grove](https://github.com/wolfadex/grove).`;
}

function groverc() {
  return `{
  "icon": {
    "style": "random",
    "angle": ${Math.floor(Math.random() * 9)},
    "color": ${JSON.stringify(randomColor())}
  }
}`;
}

function randomColor() {
  const red = Math.floor(Math.random() * 256);
  const blue = Math.floor(Math.random() * 256);
  const green = Math.floor(Math.random() * 256);

  return { red, green, blue };
}

// Elm Templates

function elmSandbox(name) {
  return `module Main exposing (Model, Msg, init, main, update, view)

import Browser
import Html exposing (..)


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }


type alias Model =
    {}


init : Model
init =
    {}


type Msg
    = NoOp


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model


view : Model -> Html Msg
view model =
    div []
        [ text "Hello, ${name}!" ]
`;
}

function elmElement(name) {
  return `module Main exposing (Model, Msg, init, main, subscriptions, update, view)

import Browser
import Html exposing (..)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


type alias Model =
    {}


init : () -> ( Model, Cmd Msg )
init _ =
    ( {}, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div []
        [ text "Hello, ${name}!" ]
`;
}
