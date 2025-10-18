import React, { useEffect, useMemo } from "react";

export const FUN_GIRLS_PUZZLE_IMAGE_SRC =
  "https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?auto=format&fit=crop&w=800&q=80" as const;

export type ImagePuzzleRevealOrder = "row" | "column" | "random";

export interface ImagePuzzleProps {
  /**
   * Source of the image that will be revealed.
   */
  imageSrc: string;
  /**
   * Alternative text for the image to keep the component accessible.
   */
  imageAlt: string;
  /**
   * Number of rows that the puzzle should be divided into.
   * A higher value produces smaller tiles.
   */
  rows?: number;
  /**
   * Number of columns that the puzzle should be divided into.
   */
  columns?: number;
  /**
   * Progress of the reveal between 0 and 1.
   * The hosting math app can map correct answers to progress increments.
   */
  progress: number;
  /**
   * Optional reveal order. Defaults to revealing row by row.
   */
  revealOrder?: ImagePuzzleRevealOrder;
  /**
   * Optional border radius for the puzzle.
   */
  borderRadius?: number | string;
  /**
   * Callback fired when the image is fully revealed.
   */
  onComplete?: () => void;
  /**
   * Optional class name to override the container styles.
   */
  className?: string;
  /**
   * Optional size of the gap between tiles.
   */
  gap?: number;
}

interface TileData {
  index: number;
  visible: boolean;
  style: React.CSSProperties;
}

const clampProgress = (value: number) => {
  if (Number.isNaN(value)) {
    return 0;
  }

  if (value < 0) {
    return 0;
  }

  if (value > 1) {
    return 1;
  }

  return value;
};

const createTileOrder = (
  rows: number,
  columns: number,
  order: ImagePuzzleRevealOrder
): number[] => {
  const totalTiles = rows * columns;

  switch (order) {
    case "column": {
      const tileIndexes: number[] = [];
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
};

const buildTiles = (
  rows: number,
  columns: number,
  revealCount: number,
  orderMap: number[]
): TileData[] =>
  orderMap.map((orderIndex, revealIndex) => {
    const row = Math.floor(orderIndex / columns);
    const column = orderIndex % columns;
    const visible = revealIndex < revealCount;

    return {
      index: orderIndex,
      visible,
      style: {
        gridRowStart: row + 1,
        gridRowEnd: row + 2,
        gridColumnStart: column + 1,
        gridColumnEnd: column + 2,
        opacity: visible ? 1 : 0,
        transition: "opacity 400ms ease",
      },
    };
  });

const getTileBackgroundStyle = (
  index: number,
  rows: number,
  columns: number,
  imageSrc: string
): React.CSSProperties => {
  const row = Math.floor(index / columns);
  const column = index % columns;

  const backgroundSize = `${columns * 100}% ${rows * 100}%`;
  const backgroundPosition = `${(column / (columns - 1 || 1)) * 100}% ${(row / (rows - 1 || 1)) * 100}%`;

  return {
    backgroundImage: `url(${imageSrc})`,
    backgroundSize,
    backgroundPosition,
    backgroundRepeat: "no-repeat",
  };
};

export const ImagePuzzle: React.FC<ImagePuzzleProps> = ({
  imageSrc,
  imageAlt,
  rows = 3,
  columns = 3,
  progress,
  revealOrder = "row",
  borderRadius = 0,
  onComplete,
  className,
  gap = 4,
}) => {
  const normalizedRows = Math.max(1, Math.round(rows));
  const normalizedColumns = Math.max(1, Math.round(columns));
  const clampedProgress = clampProgress(progress);
  const totalTiles = normalizedRows * normalizedColumns;
  const revealCount = Math.round(clampedProgress * totalTiles);

  const revealOrderMap = useMemo(
    () =>
      createTileOrder(normalizedRows, normalizedColumns, revealOrder),
    [normalizedRows, normalizedColumns, revealOrder]
  );

  const tiles = useMemo(
    () =>
      buildTiles(
        normalizedRows,
        normalizedColumns,
        revealCount,
        revealOrderMap
      ),
    [normalizedRows, normalizedColumns, revealCount, revealOrderMap]
  );

  const tileStyles = useMemo(
    () =>
      tiles.map((tile) => ({
        ...tile,
        style: {
          ...tile.style,
          ...getTileBackgroundStyle(
            tile.index,
            normalizedRows,
            normalizedColumns,
            imageSrc
          ),
        },
      })),
    [tiles, normalizedRows, normalizedColumns, imageSrc]
  );

  const containerStyles: React.CSSProperties = {
    display: "grid",
    gridTemplateRows: `repeat(${normalizedRows}, 1fr)`,
    gridTemplateColumns: `repeat(${normalizedColumns}, 1fr)`,
    gap,
    borderRadius,
    overflow: "hidden",
    position: "relative",
  };

  useEffect(() => {
    if (clampedProgress >= 1 && onComplete) {
      onComplete();
    }
  }, [clampedProgress, onComplete]);

  return (
    <div
      role="img"
      aria-label={imageAlt}
      className={className}
      style={containerStyles}
    >
      {tileStyles.map((tile) => (
        <div
          key={tile.index}
          aria-hidden={!tile.visible}
          style={tile.style}
        />
      ))}
    </div>
  );
};

export default ImagePuzzle;
