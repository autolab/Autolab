document.addEventListener("DOMContentLoaded", function() {
    const input = document.getElementById("package-name-input");
    const list  = document.getElementById("package-suggestions");

    const ver_input = document.getElementById("package-version-input");
    const ver_list  = document.getElementById("version-suggestions");

    list.style.display = "none";
    list.style.width = input.getBoundingClientRect().width + "px";

    ver_list.style.display = "none";
    ver_list.style.width = ver_input.getBoundingClientRect().width + "px";

    let lastQuery = "";

    input.addEventListener("input", function() {
        const query = input.value.trim();
        if (query === lastQuery) return;

        lastQuery = query;
        if (query.length < 2) {
            list.innerHTML = "";
            return;
        }

        fetch(`/package/search?query=${encodeURIComponent(query)}`)
            .then(response => response.json())
            .then(packages => {
                list.style.display = "block";
                list.innerHTML = "";

                packages.forEach(pkg => {
                    const item = document.createElement("li");
                    item.textContent = pkg;
                    item.addEventListener("click", () => {
                        input.value = pkg;
                        list.innerHTML = "";
                        list.style.display = "none";
                    });
                    list.appendChild(item);
                });
            });
    });

    input.addEventListener("focus", function () {
        if (list.childElementCount > 0)
            list.style.display = "block";
    })

    const input_listener = function() {
        const query = ver_input.value.trim();
        const pkg_name = input.value.trim();
        if (pkg_name.length === 0) return;

        fetch(`/package/version_search?package=${encodeURIComponent(pkg_name)}&query=${encodeURIComponent(query)}`)
            .then(response => response.json())
            .then(packages => {
                console.log("fetched!");
                ver_list.style.display = "block";
                ver_list.innerHTML = "";

                packages = ["latest"].concat(packages);

                packages.forEach(pkg => {
                    const item = document.createElement("li");
                    item.textContent = pkg;
                    item.addEventListener("click", () => {
                        ver_input.value = pkg;
                        ver_list.innerHTML = "";
                        ver_list.style.display = "none";
                    });
                    ver_list.appendChild(item);
                });
            });
    }

    ver_input.addEventListener("input", input_listener);

    ver_input.addEventListener("focus", function () {
        if (ver_list.childElementCount > 0)
            ver_list.style.display = "block";
        input_listener();
    })
});

window.addEventListener("resize", function () {
    const input = document.getElementById("package-name-input");
    const list  = document.getElementById("package-suggestions");
    const ver_input = document.getElementById("package-version-input");
    const ver_list  = document.getElementById("version-suggestions");

    list.style.width = input.getBoundingClientRect().width + "px";
    ver_list.style.width = ver_input.getBoundingClientRect().width + "px";
})