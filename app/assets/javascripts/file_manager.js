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
    $.ajax({
        url: path,
        type: "DELETE",
        success: function () {
            console.log(`Deleted: ${path}`);
            location.reload();
        },
        error: function (xhr, status, error) {
            console.error(`Failed to delete ${path}: ${error}`);
        }
    });
}

function downloadSelected(path) {
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
        },
        error: function (xhr, status, error) {
            console.error(`Failed to download ${path}: ${error}`);
        }
    });
}

function uploadFile(file, path, name) {
    let formData;
    let pathSegments = path.split('/');
    pathSegments.pop();
    let modifiedPath = pathSegments.join('/');
    formData = new FormData();
    formData.append('file', file);
    formData.append('name', name);
    $.ajax({
        url: modifiedPath,
        type: "POST",
        data: formData,
        contentType: false,
        processData: false,
        success: function () {
            console.log("Uploaded files successfully");
            location.reload();
        },
        error: function (xhr, status, error) {
            console.error(`Failed to upload files: ${error}`);
        }
    });
}

function uploadAllFiles(path) {
    let inputElement = document.getElementById('fileInput');
    let files = inputElement.files;
    if (files.length > 0) {
        for (let i = 0; i < files.length; i++) {
            let file = files[i];
            uploadFile(file, path, "");
        }
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
        uploadFile("", path, name);
    }
}

function handleDownloadClick() {
    let paths = getSelectedItems();
    if (paths.length > 0 && confirm("Download selected files?")) {
        paths.forEach(path => {
            downloadSelected(path);
        });
    }
}

function handleDeleteSelected() {
    let paths = getSelectedItems();
    if (paths.length > 0 && confirm("Delete selected files?")) {
        paths.forEach(path => {
            deleteSelected(path);
        });
    }
}

function selectDeleteSelected(path) {
    if (confirm("Delete selected file")) {
        deleteSelected(path)
    }
}

document.addEventListener('DOMContentLoaded', function() {
    const otherCheckboxes = document.querySelectorAll('.check');

    $(".check-all").click(function() {
        const isChecked = this.checked;
        otherCheckboxes.forEach(function(checkbox) {
            checkbox.checked = isChecked;
        });
    });
});
