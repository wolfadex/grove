import { ipcRenderer } from "electron";
import { Elm } from "./Main.elm";

const app = Elm.Main.init({ node: document.getElementById("root") });

app.ports.clientToMain.subscribe(function(args) {
  ipcRenderer.send("client-to-main", args);
});

ipcRenderer.on("main-to-client", function(_, args) {
  if (args.action === "PROJECT_BUNDLE") console.log(args.payload);
  app.ports.mainToClient.send(args);
});
