# ImagePuzzle Component

The `ImagePuzzle` component gradually reveals an image tile by tile. It is ideal for
math or quiz-based applications where each correct answer should uncover a portion of a
hidden picture.

For quick experimentation, a curated `FUN_GIRLS_PUZZLE_IMAGE_SRC` constant ships with a
vibrant Unsplash photo featuring two pre-teens celebrating with chalk art—an energetic
choice that resonates well with girls around ages 9 to 11.

## Usage

```tsx
import {
  ImagePuzzle,
  FUN_GIRLS_PUZZLE_IMAGE_SRC,
} from "./components/ImagePuzzle";

export function GameView({ solved, total }: { solved: number; total: number }) {
  const progress = total === 0 ? 0 : solved / total;

  return (
    <ImagePuzzle
      imageSrc={FUN_GIRLS_PUZZLE_IMAGE_SRC}
      imageAlt="Two friends celebrating with colorful chalk art"
      rows={4}
      columns={4}
      progress={progress}
      revealOrder="random"
      borderRadius={16}
      gap={6}
      onComplete={() => console.log("Puzzle revealed!" )}
    />
  );
}
```

## Simulator

To preview how the puzzle reveals tiles as progress increases, run the simulator
script. It mimics the reveal logic at several progress checkpoints and prints
tile counts alongside an ASCII grid visualization.

```bash
npm run simulator
```

## Props

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `imageSrc` | `string` | — | Source of the image to reveal. |
| `imageAlt` | `string` | — | Accessible description of the image. |
| `rows` | `number` | `3` | Number of rows in the tile grid. |
| `columns` | `number` | `3` | Number of columns in the tile grid. |
| `progress` | `number` | — | Reveal progress between `0` and `1`. |
| `revealOrder` | `'row' \| 'column' \| 'random'` | `'row'` | Order in which tiles are revealed. |
| `borderRadius` | `number \| string` | `0` | Border radius of the puzzle container. |
| `onComplete` | `() => void` | — | Callback fired once the image is fully revealed. |
| `className` | `string` | — | Optional custom class name. |
| `gap` | `number` | `4` | Gap in pixels between tiles. |

## Integration Tips

- Map the number of correct answers to the `progress` prop.
- Use higher `rows`/`columns` values for more granular reveals.
- Pair the component with celebratory animations by listening to `onComplete`.
