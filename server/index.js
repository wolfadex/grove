// Modules to control application life and create native browser window
const { app, BrowserWindow } = require("electron");
const path = require("path");
const settings = require("electron-settings");

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow;

function createWindow() {
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
  mainWindow.loadFile("dist/index.html").catch(function(err) {
    console.log("carl", err);
  });

  if (process.env.NODE_ENV !== "production") {
    // Open the DevTools.
    mainWindow.webContents.openDevTools();
  }

  // Emitted when the window is closed.
  mainWindow.on("closed", function() {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null;
  });
}

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

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on("ready", createWindow);

// Quit when all windows are closed.
app.on("window-all-closed", function() {
  // On macOS it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== "darwin") app.quit();
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
