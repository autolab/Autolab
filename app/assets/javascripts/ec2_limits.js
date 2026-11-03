function initializeEc2InstanceSelector() {
    const selector = document.getElementById("ec2-instance-selector");

    if (!selector) {
        return;
    }

    const searchInput = document.getElementById("instance-search");
    const searchResults = document.getElementById("search-results");
    const selectedInstancesContainer =
        document.getElementById("selected-instances");
    const searchContainer = document.querySelector(".instance-search-container");

    const instanceTypes = JSON.parse(
        selector.dataset.instanceTypes || "{\"instance_types\": []}"
    ).instance_types;

    const selectedInstances = new Set(
        Array.from(
            selectedInstancesContainer.querySelectorAll(".selected-instance")
        ).map((element) => element.dataset.instanceType)
    );

    function renderSearchResults() {
        const query = searchInput.value.trim().toLowerCase();

        searchResults.innerHTML = "";

        if (query.length === 0) {
            searchResults.style.display = "none";
            return;
        }

        const matches = instanceTypes
            .filter((instanceType) =>
                instanceType.toLowerCase().includes(query)
            )
            .filter((instanceType) =>
                !selectedInstances.has(instanceType)
            )
            .slice(0, 20);

        if (matches.length === 0) {
            searchResults.style.display = "none";
            return;
        }

        matches.forEach((instanceType) => {
            const result = document.createElement("div");
            result.classList.add("instance-dropdown-entry");
            result.textContent = instanceType;

            result.addEventListener("click", () => {
                addInstance(instanceType);

                searchInput.value = "";
                searchResults.innerHTML = "";
                searchResults.style.display = "none";
            });

            searchResults.appendChild(result);
        });

        searchResults.style.display = "block";
    }

    function addInstance(instanceType) {
        if (selectedInstances.has(instanceType)) {
            return;
        }

        selectedInstances.add(instanceType);

        const row = document.createElement("div");
        row.classList.add("selected-instance");
        row.dataset.instanceType = instanceType;

        const name = document.createElement("span");
        name.textContent = instanceType;

        const removeButton = document.createElement("button");
        removeButton.type = "button";
        removeButton.classList.add("remove-instance");
        removeButton.dataset.instanceType = instanceType;
        removeButton.textContent = "×";
        removeButton.setAttribute(
            "aria-label",
            `Remove ${instanceType}`
        );

        const hiddenInput = document.createElement("input");
        hiddenInput.type = "hidden";
        hiddenInput.name = "allowed_instances[]";
        hiddenInput.value = instanceType;

        row.appendChild(name);
        row.appendChild(removeButton);
        row.appendChild(hiddenInput);

        selectedInstancesContainer.appendChild(row);

        renderSearchResults();
    }

    selectedInstancesContainer.addEventListener("click", (event) => {
        const button = event.target.closest(".remove-instance");

        if (!button) {
            return;
        }

        const instanceType = button.dataset.instanceType;

        selectedInstances.delete(instanceType);
        button.closest(".selected-instance").remove();

        renderSearchResults();
    });

    searchInput.addEventListener("input", renderSearchResults);

    searchInput.addEventListener("focus", () => {
        if (searchInput.value.trim() !== "") {
            renderSearchResults();
        }
    });

    document.addEventListener("click", (event) => {
        if (!searchContainer.contains(event.target)) {
            searchResults.innerHTML = "";
            searchResults.style.display = "none";
        }
    });
}

document.addEventListener(
    "DOMContentLoaded",
    initializeEc2InstanceSelector
);