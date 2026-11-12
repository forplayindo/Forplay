import { createOptions } from "./createOptions.js";

const optionsWrapper = document.getElementById("options-wrapper");
const body = document.body;
const eye = document.getElementById("eyeSvg");

let selectedIndex = 0;
let lastKey = "";

function updateSelection() {
  const options = optionsWrapper.children;
  if (options.length === 0) return;

  if (selectedIndex < 0) selectedIndex = options.length - 1;
  if (selectedIndex >= options.length) selectedIndex = 0;

  for (let i = 0; i < options.length; i++) {
    options[i].classList.toggle("option-selected", i === selectedIndex);
  }
}

function onHover(option) {
  selectedIndex = Array.prototype.indexOf.call(optionsWrapper.children, option);
  updateSelection();
}

function clearOptions() {
  optionsWrapper.innerHTML = "";
  lastKey = "";
}

window.addEventListener("message", (event) => {
  switch (event.data.event) {
    case "scrollUp":
      selectedIndex--;
      return updateSelection();

    case "scrollDown":
      selectedIndex++;
      return updateSelection();

    case "selectCurrent": {
      const option = optionsWrapper.children[selectedIndex];
      if (option) option.click();
      return;
    }

    case "visible": {
      clearOptions();
      body.style.visibility = event.data.state ? "visible" : "hidden";
      return eye.classList.remove("eye-hover");
    }

    case "leftTarget": {
      clearOptions();
      return eye.classList.remove("eye-hover");
    }

    case "setTarget": {
      optionsWrapper.innerHTML = "";
      eye.classList.add("eye-hover");

      if (event.data.options) {
        for (const type in event.data.options) {
          event.data.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1, undefined, onHover);
          });
        }
      }

      if (event.data.zones) {
        for (let i = 0; i < event.data.zones.length; i++) {
          event.data.zones[i].forEach((data, id) => {
            createOptions("zones", data, id + 1, i + 1, onHover);
          });
        }
      }

      // same option list re-sent (e.g. canInteract refresh): keep the selection, no jump to top
      const key = Array.from(optionsWrapper.children, (o) => o.textContent).join("|");
      if (key === lastKey) {
        // no fade-in replay either
        for (const o of optionsWrapper.children) {
          o.style.animation = "none";
          o.style.opacity = "1";
        }
      } else {
        selectedIndex = 0;
      }
      lastKey = key;

      return updateSelection();
    }
  }
});
