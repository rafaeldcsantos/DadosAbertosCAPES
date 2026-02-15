let clicks = 0;

const titleEl = document.getElementById("title");
const descriptionEl = document.getElementById("description");
const buttonEl = document.getElementById("actionButton");
const counterEl = document.getElementById("counterText");

buttonEl.addEventListener("click", () => {
  clicks += 1;
  counterEl.textContent = `Clicked ${clicks} times`;
});

async function loadData() {
  try {
    const response = await fetch("./data/data.json");
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const data = await response.json();
    titleEl.textContent = data.title;
    descriptionEl.textContent = data.description;
  } catch (error) {
    titleEl.textContent = "Demo App";
    descriptionEl.textContent =
      "Could not load JSON data. If you opened this file directly, use a web server or GitHub Pages.";
    console.error("Failed to load data.json:", error);
  }
}

loadData();
