import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const imagePuzzlePath = resolve(
  __dirname,
  "../src/components/ImagePuzzle/ImagePuzzle.tsx"
);

const imagePuzzleSource = readFileSync(imagePuzzlePath, "utf8");
const imageSrcMatch = imagePuzzleSource.match(
  /FUN_GIRLS_PUZZLE_IMAGE_SRC\s*=\s*"([^"]+)"/
);
const imageSrc = imageSrcMatch?.[1] ?? "Image source not found";

function clampProgress(value) {
  if (Number.isNaN(value) || value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}

function createTileOrder(rows, columns, order) {
  const totalTiles = rows * columns;
  switch (order) {
    case "column": {
      const tileIndexes = [];
      for (let column = 0; column < columns; column += 1) {
        for (let row = 0; row < rows; row += 1) {
          tileIndexes.push(row * columns + column);
        }
      }
      return tileIndexes;
    }
    case "random": {
      const tileIndexes = Array.from({ length: totalTiles }, (_, index) => index);
      for (let i = tileIndexes.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1));
        [tileIndexes[i], tileIndexes[j]] = [tileIndexes[j], tileIndexes[i]];
      }
      return tileIndexes;
    }
    case "row":
    default:
      return Array.from({ length: totalTiles }, (_, index) => index);
  }
}

function buildTiles(rows, columns, revealCount, orderMap) {
  return orderMap.map((orderIndex, revealIndex) => {
    const row = Math.floor(orderIndex / columns);
    const column = orderIndex % columns;
    const visible = revealIndex < revealCount;

    return {
      index: orderIndex,
      row,
      column,
      visible,
    };
  });
}

function renderGrid(tiles, rows, columns) {
  const grid = Array.from({ length: rows }, () =>
    Array.from({ length: columns }, () => "□")
  );

  tiles.forEach((tile) => {
    grid[tile.row][tile.column] = tile.visible ? "■" : "□";
  });

  return grid.map((row) => row.join(" ")).join("\n");
}

const rows = 4;
const columns = 4;
const revealOrder = "row";
const progressPoints = [0, 0.25, 0.5, 0.75, 1];

const orderMap = createTileOrder(rows, columns, revealOrder);

console.log(`ImagePuzzle simulator for a ${rows}x${columns} grid`);
console.log(`Curated image source: ${imageSrc}`);
console.log("");

progressPoints.forEach((progress) => {
  const clamped = clampProgress(progress);
  const revealCount = Math.round(clamped * rows * columns);
  const tiles = buildTiles(rows, columns, revealCount, orderMap);
  const visibleTiles = tiles.filter((tile) => tile.visible).length;

  console.log(`Progress ${(progress * 100).toFixed(0)}%`);
  console.log(`Revealed tiles: ${visibleTiles}/${rows * columns}`);
  console.log(renderGrid(tiles, rows, columns));
  console.log("");
});
