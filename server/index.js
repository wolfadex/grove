// Modules to control application life and create native browser window
const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const { spawn } = require("child_process");
const fs = require("fs-extra");
const settings = require("electron-settings");

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow;

function createWindow(startupConfig) {
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
    mainWindow.webContents.send("startup-config", startupConfig);
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
app.on("ready", initialize);

// Quit when all windows are closed.
app.on("window-all-closed", function() {
  // On macOS it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== "darwin") app.quit();
});

app.on("activate", function() {
  // On macOS it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (mainWindow === null) initialize();
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

async function initialize() {
  const rootPath = settings.get("root");

  if (rootPath == null) {
    createWindow(null);
  } else {
    try {
      const projects = await getProjectsFromRoot(rootPath);
      const userName = settings.get("name");
      const userEmail = settings.get("email");

      createWindow({ rootPath, projects, userName, userEmail });
    } catch (error) {
      devLog("Error loading root path", error);
      createWindow(null);
    }
  }
}

async function getProjectsFromRoot(rootPath) {
  const filesAndDirs = await fs.readdir(rootPath, { withFileTypes: true });
  const projects = {};

  for (let fileOrDir of filesAndDirs) {
    if (fileOrDir.isDirectory && fileOrDir.name !== ".DS_Store") {
      try {
        const projectPath = path.resolve(rootPath, fileOrDir.name);
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

  return projects;
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

  const packageJson = filesAndDirs.find(function(fileOrDir) {
    return fileOrDir.name === "package.json";
  });

  if (packageJson == null) {
    throw new Error(
      "Expected to find a package.json. This Grove project seems to be corrupted or manually modified.",
    );
  }

  try {
    const packageJsonContents = await fs.readFile(
      path.resolve(projectPath, packageJson.name),
    );
    const { name } = JSON.parse(packageJsonContents);

    return { projectPath, projectName: name };
  } catch (error) {
    throw new Error(error);
  }
}

ipcMain.on("new-root", async function(e, newRootPath) {
  settings.set("root", newRootPath);
  devLog("Saved root", newRootPath);

  try {
    const projects = await getProjectsFromRoot(newRootPath);

    e.reply("load-projects", projects);
  } catch (error) {
    devLog("New root error", error);
  }
});

ipcMain.on("new-project", async function(e, projectData) {
  try {
    const projectPath = path.resolve(projectData.rootPath, projectData.name);

    await fs.mkdir(projectPath);
    // Copy over template files
    await fs.copy(path.resolve(__dirname, "template/common"), projectPath);
    await fs.copy(path.resolve(__dirname, "template/sandbox"), projectPath);
    // Rename .gitignore
    await fs.move(
      path.resolve(projectPath, "gitignore"),
      path.resolve(projectPath, ".gitignore"),
    );
    // Rename .groverc
    await fs.move(
      path.resolve(projectPath, "groverc"),
      path.resolve(projectPath, ".groverc"),
    );
    await fs.writeFile(
      path.resolve(projectPath, "package.json"),
      `{
  "name": "${projectData.name}",
  "version": "1.0.0",
  "author": {
    "name": "${projectData.userName}",
    "email": "${projectData.userEmail}"
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
}`,
    );
    await exec("yarn", { cwd: projectPath });

    try {
      const projects = await getProjectsFromRoot(projectData.rootPath);

      e.reply("load-projects", projects);
    } catch (error) {
      devLog("Re-get projects error", error);
    }

    e.reply("project-created", projectData.name);
  } catch (error) {
    console.log("create error", error);
    e.reply("error-creating-project", { name: projectData.name, error });
  }
});

function exec(command, options) {
  return new Promise(function(resolve, reject) {
    const response = spawn(command, options);
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

ipcMain.on("set-name", function(e, name) {
  settings.set("name", name);
});

ipcMain.on("set-email", function(e, email) {
  settings.set("email", email);
});
