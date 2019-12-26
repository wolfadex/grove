import { ipcRenderer } from "electron";
import { Elm } from "./Main.elm";

const app = Elm.Main.init({ node: document.getElementById("root") });
