const dropzone = document.getElementById("dropzone");
const fileInput = document.getElementById("file-input");
const filesBody = document.getElementById("files-body");
const filesCount = document.getElementById("files-count");
const emptyState = document.getElementById("empty-state");

function formatSize(bytes) {
  if (!bytes && bytes !== 0) return "-";
  const units = ["B", "KB", "MB", "GB"];
  let value = Number(bytes);
  let i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i += 1;
  }
  return `${value.toFixed(1)} ${units[i]}`;
}

function formatDate(isoString) {
  if (!isoString) return "-";
  return new Date(isoString).toLocaleString("es-MX", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

function renderFiles(files) {
  filesBody.innerHTML = "";
  filesCount.textContent = files.length ? `${files.length} archivo(s)` : "";
  emptyState.hidden = files.length !== 0;

  files
    .sort((a, b) => (a.updated < b.updated ? 1 : -1))
    .forEach((file) => {
      const row = document.createElement("tr");

      const nameCell = document.createElement("td");
      nameCell.textContent = file.name;

      const sizeCell = document.createElement("td");
      sizeCell.textContent = formatSize(file.size);

      const updatedCell = document.createElement("td");
      updatedCell.textContent = formatDate(file.updated);

      const actionsCell = document.createElement("td");

      const viewBtn = document.createElement("button");
      viewBtn.textContent = "Ver";
      viewBtn.className = "row-action";
      viewBtn.addEventListener("click", () => openFile(file.name));

      const deleteBtn = document.createElement("button");
      deleteBtn.textContent = "Eliminar";
      deleteBtn.className = "row-action danger";
      deleteBtn.addEventListener("click", () => removeFile(file.name));

      actionsCell.append(viewBtn, deleteBtn);
      row.append(nameCell, sizeCell, updatedCell, actionsCell);
      filesBody.appendChild(row);
    });
}

async function loadFiles() {
  try {
    const response = await fetch("/api/files");
    if (!response.ok) throw new Error(`status ${response.status}`);
    renderFiles(await response.json());
  } catch (err) {
    console.error("Error cargando archivos:", err);
    alert("No se pudo cargar la lista de documentos. Revisa la consola del navegador.");
  }
}

async function openFile(name) {
  try {
    const response = await fetch(`/api/files/${encodeURIComponent(name)}/download-url`);
    if (!response.ok) throw new Error(`status ${response.status}`);
    const { download_url: downloadUrl } = await response.json();
    window.open(downloadUrl, "_blank", "noopener");
  } catch (err) {
    console.error("Error generando enlace de descarga:", err);
    alert("No se pudo generar el enlace del archivo.");
  }
}

async function removeFile(name) {
  if (!confirm(`¿Eliminar "${name}"? Esta acción no se puede deshacer.`)) return;

  try {
    const response = await fetch(`/api/files/${encodeURIComponent(name)}`, { method: "DELETE" });
    if (!response.ok) throw new Error(`status ${response.status}`);
    await loadFiles();
  } catch (err) {
    console.error("Error eliminando archivo:", err);
    alert("No se pudo eliminar el archivo.");
  }
}

async function uploadFile(file) {
  try {
    const urlResponse = await fetch("/api/files/upload-url", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        filename: file.name,
        content_type: file.type || "application/octet-stream",
      }),
    });

    if (!urlResponse.ok) {
      const body = await urlResponse.json().catch(() => ({}));
      alert(`No se pudo iniciar la subida de "${file.name}": ${body.error || urlResponse.status}`);
      return;
    }

    const { upload_url: uploadUrl } = await urlResponse.json();

    // El navegador sube directo a Cloud Storage; Cloud Run nunca ve el contenido.
    const putResponse = await fetch(uploadUrl, {
      method: "PUT",
      headers: { "Content-Type": file.type || "application/octet-stream" },
      body: file,
    });

    if (!putResponse.ok) {
      alert(`Error al subir "${file.name}" (status ${putResponse.status}).`);
      return;
    }

    await loadFiles();
  } catch (err) {
    // Un fetch() bloqueado por CORS llega aquí como error de red genérico,
    // no como una respuesta con status: por eso el try/catch es necesario.
    console.error(`Error subiendo "${file.name}":`, err);
    alert(`No se pudo subir "${file.name}". Revisa la consola del navegador (F12) para más detalle.`);
  }
}

function handleFiles(fileList) {
  Array.from(fileList).forEach(uploadFile);
}

["dragenter", "dragover"].forEach((eventName) => {
  dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    dropzone.classList.add("drag-active");
  });
});

["dragleave", "drop"].forEach((eventName) => {
  dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    dropzone.classList.remove("drag-active");
  });
});

dropzone.addEventListener("drop", (event) => {
  handleFiles(event.dataTransfer.files);
});

fileInput.addEventListener("change", (event) => {
  handleFiles(event.target.files);
  fileInput.value = "";
});

loadFiles();
