import { ipcRenderer, remote } from "electron";
import { Elm } from "./Main.elm";

const app = Elm.Main.init({ node: document.getElementById("root") });

app.ports.createProject.subscribe(function(projectData) {
  ipcRenderer.send("new-project", projectData);
});

app.ports.saveEditor.subscribe(function(editor) {
  ipcRenderer.send("save-editor", editor);
});

app.ports.developProject.subscribe(function(args) {
  ipcRenderer.send("dev-project", args);
});

app.ports.confirmDelete.subscribe(async function([projectPath, name]) {
  const { response } = await remote.dialog.showMessageBox({
    type: "question",
    buttons: ["Cancel", "Delete"],
    title: "Delete Project?",
    message: `Are you sure you want to delete ${name}?`,
  });

  if (response === 1) {
    ipcRenderer.send("delete-confirmed", projectPath);
  }
});

app.ports.downloadEditor.subscribe(function(url) {
  ipcRenderer.send("download-editor", url);
});

ipcRenderer.on("startup-config", function(e, startupConfig) {
  app.ports.mainStarted.send(startupConfig);
});

ipcRenderer.on("load-project", function(e, project) {
  app.ports.loadProject.send(project);
});

ipcRenderer.on("load-projects", function(e, projects) {
  app.ports.loadProjects.send(projects);
});

ipcRenderer.on("project-created", function(e, name) {
  app.ports.projectCreated.send(name);
});

ipcRenderer.on("delete-project", function(e, id) {
  app.ports.projectDeleted.send(id);
});
