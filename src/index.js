import { ipcRenderer, remote } from "electron";
import { Elm } from "./Main.elm";

const app = Elm.Main.init({ node: document.getElementById("root") });

app.ports.getRootPath.subscribe(async function() {
  const response = await remote.dialog.showOpenDialog({
    title: "Projects Root",
    buttonLabel: "Set Root",
    properties: ["openDirectory", "createDirectory"],
  });

  if (!response.canceled) {
    app.ports.setRootPath.send(response.filePaths[0]);
  }
});

app.ports.saveRoot.subscribe(function(newRootPath) {
  ipcRenderer.send("new-root", newRootPath);
});

ipcRenderer.on("startup-config", function(e, startupConfig) {
  app.ports.mainStarted.send(startupConfig);
});

ipcRenderer.on("load-projects", function(e, projects) {
  app.ports.loadProjects.send(projects);
});
