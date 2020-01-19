// Modules to control application life and create native browser window
const { app, BrowserWindow, ipcMain, shell, dialog } = require("electron");
const path = require("path");
const { spawn } = require("child_process");
const fs = require("fs-extra");
const launch = require("launch-editor");
const settings = require("electron-settings");
const Bundler = require("parcel-bundler");
const elmLicenseFinder = require("elm-license-finder");
const templates = require("./templates.js");

const PROJECTS_ROOT = path.resolve(__dirname, "user_projects");
// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow;

function createWindow(startupConfig) {
  const editor = settings.get("editor");
  const { x, y, width = 800, height = 600 } = settings.get("window") || {};
  // Create the browser window.
  mainWindow = new BrowserWindow({
    width,
    height,
    x,
    y,
    webPreferences: {
      nodeIntegration: true,
      // preload: path.join(__dirname, "preload.js"),
    },
  });

  mainWindow.on("resize", saveWindow);
  mainWindow.on("move", saveWindow);

  // and load the index.html of the app.
  mainWindow.loadFile("dist/index.html");

  if (process.env.NODE_ENV !== "production") {
    // Open the DevTools.
    mainWindow.webContents.openDevTools();
  }

  mainWindow.webContents.on("did-finish-load", function() {
    // sendToClient("MAIN_STARTED", { editor });
    loadProjects();
  });

  // Emitted when the window is closed.
  mainWindow.on("closed", function() {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null;
  });
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on("ready", createWindow);

// Quit when all windows are closed.
app.on("window-all-closed", function() {
  // On macOS it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== "darwin") {
    killAllServers();
    app.quit();
  }
});

app.on("activate", function() {
  // On macOS it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (mainWindow === null) createWindow();
});

function devLog() {
  if (process.env.NODE_ENV !== "production") {
    console.log(...arguments);
  }
}

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and require them here.

let saveWindowDebounce;
function saveWindow() {
  if (mainWindow != null) {
    if (saveWindowDebounce != null) {
      clearTimeout(saveWindowDebounce);
    }
    saveWindowDebounce = setTimeout(function() {
      const bounds = mainWindow.getNormalBounds();
      settings.set("window", bounds);
      devLog("Window saved", bounds);
    }, 800);
  }
}

async function loadProjects() {
  const filesAndDirs = await fs.readdir(PROJECTS_ROOT, { withFileTypes: true });
  const projects = {};

  for (let fileOrDir of filesAndDirs) {
    if (fileOrDir.isDirectory() && fileOrDir.name !== ".DS_Store") {
      try {
        const projectPath = path.resolve(PROJECTS_ROOT, fileOrDir.name);
        const project = await loadProject(projectPath);

        projects[projectPath] = {
          ...project,
          directoryName: fileOrDir.name,
        };
      } catch (error) {
        devLog("Error loading project", error);
      }
    }
  }

  sendToClient("LOAD_PROJECTS", projects);
}

async function loadProject(projectPath) {
  const filesAndDirs = await fs.readdir(projectPath, { withFileTypes: true });
  const isGroveProject = filesAndDirs.some(function(fileOrDir) {
    return fileOrDir.name === ".groverc";
  });

  if (!isGroveProject) {
    // Currently only support projects created by Grove
    throw new Error("Expected to find a file named '.groverc'.");
  }

  // const packageJson = filesAndDirs.find(function(fileOrDir) {
  //   return fileOrDir.name === "package.json";
  // });

  // if (packageJson == null) {
  //   throw new Error(
  //     "Expected to find package.json. This Grove project seems to be corrupted or manually modified.",
  //   );
  // }

  const elmJson = filesAndDirs.find(function(fileOrDir) {
    return fileOrDir.name === "elm.json";
  });

  if (elmJson == null) {
    throw new Error(
      "Expected to find elm.json. This Grove project seems to be corrupted or manually modified.",
    );
  }

  try {
    // const packageJsonContents = await fs.readFile(
    //   path.resolve(projectPath, packageJson.name),
    // );
    // const { name } = JSON.parse(packageJsonContents);
    const groverc = await fs.readFile(path.resolve(projectPath, ".groverc"));
    const { name, author } = JSON.parse(groverc);
    // const elmJsonContents = await fs.readFile(
    //   path.resolve(projectPath, elmJson.name),
    // );
    // const { dependencies } = JSON.parse(elmJsonContents);
    const dependencies = elmLicenseFinder(projectPath);

    return { projectPath, projectName: name, dependencies, author };
  } catch (error) {
    throw new Error(error);
  }
}

function exec(command, args, options) {
  return new Promise(function(resolve, reject) {
    console.log(command);
    const response = spawn(command, args, options);
    const errors = [];
    const datas = [];

    response.stderr.on("data", function(error) {
      errors.push(error);
    });
    response.stdout.on("data", function(data) {
      datas.push(data);
    });
    response.on("exit", function(code) {
      if (code === 0) {
        resolve(datas);
      } else {
        reject(errors);
      }
    });
  });
}

const parcelServers = {};

function killAllServers() {
  Object.values(parcelServers).forEach(function(server) {
    server.close();
  });
}

async function deleteProject(projectPath) {
  await fs.remove(path.resolve(PROJECTS_ROOT, projectPath));

  sendToClient("PROJECT_DELETED", projectPath);

  const server = parcelServers[projectPath];

  if (server != null) {
    server.close();
    delete parcelServers[projectPath];
  }
}

ipcMain.on("test-project", function(e, projectPath) {
  // TODO:
});

ipcMain.on("client-to-main", async function(_, { action, payload }) {
  switch (action) {
    case "CREATE_PROJECT":
      {
        const { name, author, elmProgram } = payload;

        try {
          const projectPath = path.resolve(PROJECTS_ROOT, name);

          await fs.mkdir(projectPath);
          // Copy over template files
          await fs.copy(
            path.resolve(__dirname, "template/common"),
            projectPath,
          );
          // Rename .gitignore
          await fs.move(
            path.resolve(projectPath, "gitignore"),
            path.resolve(projectPath, ".gitignore"),
          );
          // Create .groverc
          await fs.writeFile(
            path.resolve(projectPath, ".groverc"),
            templates.groverc(name, author),
          );
          // Create index.html
          await fs.writeFile(
            path.resolve(projectPath, "src/index.html"),
            templates.html(name),
          );
          // Create Elm file
          let elmTemplate;
          switch (elmProgram) {
            case "application":
              elmTemplate = templates.elmApplication;
              break;
            case "document":
              elmTemplate = templates.elmDocument;
              break;
            case "element":
              elmTemplate = templates.elmElement;
              break;
            default:
              elmTemplate = templates.elmSandbox;
              break;
          }
          await fs.writeFile(
            path.resolve(projectPath, "src/Main.elm"),
            elmTemplate(name),
          );

          try {
            const project = await loadProject(projectPath);
            sendToClient("LOAD_PROJECT", {
              [projectPath]: { ...project, directoryName: name },
            });
          } catch (error) {
            devLog("Re-get projects error", error);
          }

          sendToClient("PROJECT_CREATED", name);
        } catch (error) {
          devLog("Create project error", error);
          sendToClient("ERROR_CREATING_PROJECT", { name: name, error });
        }
      }
      break;
    case "DEVELOP_PROJECT":
      {
        devLog("Open editor", payload.editor);
        launch(
          path.resolve(payload.projectPath),
          payload.editor,
          (fileName, errorMsg) => {
            devLog(fileName, errorMsg);
          },
        );

        if (parcelServers[payload.projectPath] == null) {
          devLog("Start parcel");
          const entryFile = path.join(payload.projectPath, "src/index.html");
          const bundler = new Bundler(entryFile, {
            watch: true,
            minify: false,
            outDir: path.resolve(payload.projectPath, "dist"),
            cacheDir: path.resolve(payload.projectPath, ".cache"),
          });
          const server = await bundler.serve();
          parcelServers[payload.projectPath] = server;
          shell.openExternal(`http://localhost:${server.address().port}`);
          sendToClient("PROJECT_SERVER_STARTED", payload.projectPath);
        } else {
          devLog("Parcel already running for this project");
          shell.openExternal(
            `http://localhost:${
              parcelServers[payload.projectPath].address().port
            }`,
          );
        }
      }
      break;
    case "STOP_DEV_SERVER":
      {
        const server = parcelServers[payload.projectPath];

        if (server) {
          server.close();
          delete parcelServers[payload.projectPath];
          sendToClient("PROJECT_SERVER_STOPPED", payload.projectPath);
        }
      }
      break;
    case "SAVE_EDITOR":
      {
        settings.set("editor", payload);
      }
      break;
    case "CONFIRM_DELETE":
      {
        const { response } = await dialog.showMessageBox({
          type: "question",
          buttons: ["Cancel", "Delete"],
          title: "Delete Project?",
          message: `Are you sure you want to delete ${payload.name}?`,
        });

        if (response === 1) {
          deleteProject(payload.projectPath);
        }
      }
      break;
    case "EJECT_PROJECT":
      {
        // Get output directory
        const response = await dialog.showOpenDialog({
          title: "Where to Eject to",
          buttonLabel: "Eject",
          properties: ["openDirectory", "createDirectory"],
        });

        if (!response.canceled) {
          // Add remaining files needed for an ejected project
          const groverc = await fs.readFile(
            path.resolve(PROJECTS_ROOT, payload, ".groverc"),
          );
          const { name } = JSON.parse(groverc);
          // Copy over eject files
          await fs.copy(path.resolve(__dirname, "template/eject"), payload);
          // Create README
          await fs.writeFile(
            path.resolve(payload, "README.md"),
            templates.readme(name),
          );
          // Create package.json
          await fs.writeFile(
            path.resolve(payload, "package.json"),
            templates.packageJson(name),
          );

          const outputPath = path.resolve(response.filePaths[0], name);
          // Eject
          await fs.copy(path.resolve(PROJECTS_ROOT, payload), outputPath);
          // Delete old project files
          await deleteProject(payload);
          // Show ejected project to user
          shell.showItemInFolder(outputPath);
        }
      }
      break;
    case "BUILD_PROJECT":
      {
        try {
          // Clear any previous build
          await fs.remove(path.resolve(PROJECTS_ROOT, payload, "dist"));
        } catch (_) {
          // Ignore delete if it doesn't exist
        }

        try {
          const entryFile = path.join(payload, "src/index.html");
          const bundler = new Bundler(entryFile, {
            watch: false,
            minify: true,
            outDir: path.resolve(payload, "dist"),
            cacheDir: path.resolve(payload, ".cache"),
            production: true,
          });

          bundler.on("bundled", function(bundle) {
            sendToClient("PROJECT_BUNDLE", {
              projectPath: payload,
              bundle: parseBundle(bundle),
            });
          });

          await bundler.bundle();
          shell.showItemInFolder(path.join(payload, "dist"));
          sendToClient("PROJECT_BUILT", payload);
        } catch (error) {
          devLog("Build error", error);
          sendToClient("PROJECT_BUILD_ERROR", { projectPath: payload, error });
        }
        // TODO: Should more happen here? Maybe hookup to a static host?
      }
      break;
  }
});

function sendToClient(action, payload) {
  if (mainWindow != null && mainWindow.webContents) {
    mainWindow.webContents.send("main-to-client", { action, payload });
  }
}

function parseBundle(bundle) {
  const children = [];

  if (bundle.childBundles) {
    for (let [child] of bundle.childBundles.entries()) {
      children.push(parseBundle(child));
    }
  }

  return {
    ...bundle,
    children,
  };
}
