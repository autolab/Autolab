function rename(path) {
    let new_name = prompt("Enter the new name:");
    if (new_name !== null) {
        let rel_path = decodeURIComponent(path.split("/file_manager/")[1]);
        $.ajax({
            url: "/file_manager/" + rel_path,
            type: "PUT",
            data: { new_name: new_name, relative_path: rel_path},
            success: function(data) {
                console.log(`Renamed: ${rel_path}`)
                location.reload();
            }
        });
    }
}

function deleteSelected(path) {
    return new Promise(function(resolve, reject) {
        $.ajax({
            url: path,
            type: "DELETE",
            success: function () {
                console.log(`Deleted: ${path}`);
                resolve();
            },
            error: function (xhr, status, error) {
                reject(error);
            }
        });
    })
}

function downloadSelected(path) {
    return new Promise(function(resolve, reject) {
        $.ajax({
            url: '/file_manager/download_tar/',
            type: "POST",
            data: {
                path: path
            },
            success: function (data) {
                let blob = new Blob([data], { type: 'application/x-tar' });
                let url = URL.createObjectURL(blob);
                let a = document.createElement('a');
                a.href = url;
                let parts = path.split("/")
                a.download = parts[parts.length - 1]
                a.style.display = 'none';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
                console.log(`Downloaded: ${data.filename}`);
                resolve();
            },
            error: function (xhr, status, error) {
                console.error(`Failed to download ${path}: ${error}`);
                reject(error);
            }
        });
    })
}

function uploadFile(file, path, name) {
    let formData;
    let pathSegments = path.split('/');
    pathSegments.pop();
    let modifiedPath = pathSegments.join('/');
    formData = new FormData();
    formData.append('file', file);
    formData.append('name', name);
    return new Promise(function(resolve, reject) {
        $.ajax({
            url: modifiedPath,
            type: "POST",
            data: formData,
            contentType: false,
            processData: false,
            success: function () {
                console.log("Uploaded file successfully");
                resolve();
            },
            error: function (xhr, status, error) {
                console.error(`Failed to upload file: ${error}`);
                reject(error);
            }
        });
    });
}

function uploadAllFiles(path) {
    let inputElement = document.getElementById('fileInput');
    let files = inputElement.files;
    const uploadPromises = [];
    for (let i = 0; i < files.length; i++) {
        let file = files[i];
        uploadPromises.push(uploadFile(file, path, ""));
    }
    if (files.length > 0) {
        Promise.all(uploadPromises)
        .then(() => {
            alert("All files uploaded successfully.");
            location.reload();
        })
        .catch((error) => {
            alert("Some files failed to upload successfully. Ensure that you are not in the root directory, the file is smaller than 1 GB, and does not already exist.");
            location.reload();
        });
    } else {
        console.log('No files selected.');
    }
}

function getSelectedItems() {
    let selectedItems = $("input[type='checkbox'][class='check']:checked");
    let paths = [];
    selectedItems.each(function(index, element) {
        paths.push(jQuery(element).prop('value'));
    });
    return paths
}

function createFolder(path) {
    let name = prompt("Name of folder: ");
    if (name !== "" && name !== null) {
        uploadFile("", path, name)
            .then(() => {
                alert("Folder created successfully.");
                location.reload();
            })
            .catch((error) => {
                alert("Failed to create folder. Check that you are not in the root directory and that the tile/folder does not already exist.");
            })
        ;
    }
}

function handleDownloadClick() {
    let paths = getSelectedItems();
    if (paths.length > 0 && confirm("Download selected files?")) {
        let downloadPromises = [];
        paths.forEach(path => {
            downloadPromises.push(downloadSelected(path));
        });
        Promise.all(downloadPromises)
            .then(() => {
                alert("All files downloaded successfully.");
            })
            .catch((error) => {
                alert("Some files failed to download.");
            });
    }
}

function handleDeleteSelected() {
    let paths = getSelectedItems();
    if (paths.length > 0 && confirm("Delete selected files?")) {
        let deletePromises = [];
        paths.forEach(path => {
            deletePromises.push(deleteSelected(path));
        });
        Promise.all(deletePromises)
            .then(() => {
                alert("All files deleted successfully.");
                location.reload();
            })
            .catch((error) => {
                alert("Unable to delete files in the root directory.")
                location.reload();
            });
    }
}

function selectDeleteSelected(path) {
    if (confirm("Delete selected file")) {
        deleteSelected(path)
            .then(() => {
                alert("File deleted successfully.")
                location.reload();
            })
            .catch(() => {
                alert("Unable to delete files in the root directory.")
                location.reload();
            })
    }
}

function updateButtonStatesAndStyle(button, parent) {
    parent.style.backgroundColor = button.disabled ? "grey" : "rgba(153, 0, 0, 0.9)";
    parent.style.pointerEvents = button.disabled ? "none" : "auto";
}

function handleSelectionChange() {
    const downloadBtn = document.getElementById('download-selected');
    const deleteBtn = document.getElementById('delete-selected');
    const downloadParent = document.getElementById('download-parent');
    const deleteParent = document.getElementById('delete-parent');

    let selectedItems = getSelectedItems();
    downloadBtn.disabled = selectedItems.length === 0;
    updateButtonStatesAndStyle(downloadBtn, downloadParent);

    deleteBtn.disabled = selectedItems.length === 0;
    updateButtonStatesAndStyle(deleteBtn, deleteParent);
}

document.addEventListener('DOMContentLoaded', function() {
    const otherCheckboxes = document.querySelectorAll('.check');
    handleSelectionChange();

    $(".check-all").click(function() {
        const isChecked = this.checked;
        otherCheckboxes.forEach(function(checkbox) {
            checkbox.checked = isChecked;
        });
        handleSelectionChange();
    });

    $(".check").click(function() {
        handleSelectionChange();
    })
});
