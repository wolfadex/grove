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

app.ports.setName.subscribe(function(name) {
  ipcRenderer.send("set-name", name);
});

app.ports.setEmail.subscribe(function(email) {
  ipcRenderer.send("set-email", email);
});

app.ports.saveRoot.subscribe(function(newRootPath) {
  ipcRenderer.send("new-root", newRootPath);
});

app.ports.createProject.subscribe(function(projectData) {
  ipcRenderer.send("new-project", projectData);
});

app.ports.saveEditor.subscribe(function(editor) {
  ipcRenderer.send("save-editor", editor);
});

app.ports.developProject.subscribe(function(args) {
  ipcRenderer.send("dev-project", args);
});

app.ports.confirmDelete.subscribe(async function([
  projectPath,
  name,
  rootPath,
]) {
  const { response } = await remote.dialog.showMessageBox({
    type: "question",
    buttons: ["Cancel", "Delete"],
    title: "Delete Project?",
    message: `Are you sure you want to delete ${name}?`,
  });

  if (response === 1) {
    ipcRenderer.send("delete-confirmed", [projectPath, rootPath]);
  }
});

ipcRenderer.on("startup-config", function(e, startupConfig) {
  app.ports.mainStarted.send(startupConfig);
});

ipcRenderer.on("load-projects", function(e, projects) {
  app.ports.loadProjects.send(projects);
});

ipcRenderer.on("project-created", function(e, name) {
  app.ports.projectCreated.send(name);
});
