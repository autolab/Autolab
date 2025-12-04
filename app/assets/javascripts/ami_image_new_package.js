document.addEventListener("DOMContentLoaded", function() {
    const input = document.getElementById("package-name-input");
    const list  = document.getElementById("package-suggestions");
    list.style.display = "none";
    list.style.width = input.getBoundingClientRect().width + "px";

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
});

window.addEventListener("resize", function () {
    console.log("resize");

    const input = document.getElementById("package-name-input");
    const list  = document.getElementById("package-suggestions");

    list.style.width = input.getBoundingClientRect().width + "px";
})