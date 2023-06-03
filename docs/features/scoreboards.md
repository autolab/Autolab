# Scoreboards

Scoreboards are created by the output of [Autograders](/lab/#writing-autograders). They anonymously rank students submitted assignments inspiring health competition and desire to improve. They are simple and highly customizable. Scoreboard's can be added/edited on the edit assessment screen (`/courses/<course>/assessments/<assessment>/edit`).

![Scoreboard Edit](/images/scoreboard_edit.png)

In general, scoreboards are configured using a JSON string.

## Default Scoreboard

The default scoreboard displays the total problem scores, followed by each individual problem score, sorted in descending order by the total score.

## Custom Scoreboards

Autograded assignments have the option of creating custom scoreboards. You can specify your own custom scoreboard using a JSON column specification.

The column spec consists of a "scoreboard" object, which is an array of JSON objects, where each object describes a column.

**Example:** a scoreboard with one column, called `Score`.

```json
{
    "scoreboard": [{ "hdr": "Score" }]
}
```

A custom scoreboard sorts the first three columns, from left to right, in descending order. You can change the default sort order for a particular column by adding an optional "asc:1" element to its hash.

**Example:** Scoreboard with two columns, "Score" and "Ops", with "Score" sorted descending, and then "Ops" ascending:

```json
{
    "scoreboard": [{ "hdr": "Score" }, { "hdr": "Ops", "asc": 1 }]
}
```

## Scoreboard Entries

The values for each row in a custom scoreboard come directly from a `scoreboard` array object in the autoresult string produced by the Tango, the autograder.

**Example:** Autoresult returning the score (97) for a single autograded problem called `autograded`, and a scoreboard entry with two columns: the autograded score (`Score`) and the number of operations (`Ops`):

```json
{
    "scores": {
        "autograded": 97
    },
    "scoreboard": [97, 128]
}
```

For more information on how to use Autograders and Scoreboards together, visit the [Guide for Lab Authors](/lab/).
