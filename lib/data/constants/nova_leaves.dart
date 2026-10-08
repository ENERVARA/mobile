/// Individual leaf sprites for Nova's chat-thread tree, positioned in the exact
/// pixel space of `assets/images/nova/tree.png` (both source canvases are
/// 1280x1280, so these percentages align 1:1 with the displayed tree image).
///
/// Ordered bottom-of-canopy first — the thread reveals them in this order as it
/// scrolls down. Generated 1:1 from the web app's `constants/novaLeaves.ts`.
class NovaLeaf {
  final int id;
  final String file;
  final double xPct;
  final double yPct;
  final double wPct;
  final double hPct;
  const NovaLeaf(this.id, this.file, this.xPct, this.yPct, this.wPct, this.hPct);

  String get asset => 'assets/images/nova/leaves/$file';
}

const List<NovaLeaf> kNovaLeaves = [
  NovaLeaf(1, 'leaf-01.png', 65.703, 57.188, 5.703, 3.281),
  NovaLeaf(2, 'leaf-02.png', 26.797, 51.172, 6.562, 4.375),
  NovaLeaf(3, 'leaf-03.png', 65.859, 49.375, 3.203, 5.312),
  NovaLeaf(4, 'leaf-04.png', 69.219, 48.203, 11.641, 6.016),
  NovaLeaf(5, 'leaf-05.png', 22.891, 45.625, 10.625, 6.641),
  NovaLeaf(6, 'leaf-06.png', 75.938, 44.844, 5.859, 2.969),
  NovaLeaf(7, 'leaf-07.png', 37.266, 43.359, 6.953, 4.844),
  NovaLeaf(8, 'leaf-08.png', 56.875, 42.969, 5.703, 5.625),
  NovaLeaf(9, 'leaf-09.png', 19.062, 42.5, 9.219, 5.469),
  NovaLeaf(10, 'leaf-10.png', 74.219, 40.156, 8.203, 4.375),
  NovaLeaf(11, 'leaf-11.png', 17.109, 39.141, 6.328, 3.594),
  NovaLeaf(12, 'leaf-12.png', 61.016, 36.484, 12.734, 5.859),
  NovaLeaf(13, 'leaf-13.png', 77.344, 35.781, 5.078, 4.453),
  NovaLeaf(14, 'leaf-14.png', 26.25, 33.516, 13.828, 7.969),
  NovaLeaf(15, 'leaf-15.png', 41.406, 33.75, 7.5, 7.5),
  NovaLeaf(16, 'leaf-16.png', 18.359, 33.672, 8.281, 5.391),
  NovaLeaf(17, 'leaf-17.png', 74.219, 33.75, 3.75, 5.078),
  NovaLeaf(18, 'leaf-18.png', 53.438, 26.016, 9.297, 14.141),
  NovaLeaf(19, 'leaf-19.png', 72.109, 28.359, 10.859, 5.391),
  NovaLeaf(20, 'leaf-20.png', 63.359, 25.703, 9.922, 7.266),
  NovaLeaf(21, 'leaf-21.png', 37.578, 20.156, 9.688, 14.062),
  NovaLeaf(22, 'leaf-22.png', 21.875, 23.125, 9.688, 8.047),
  NovaLeaf(23, 'leaf-23.png', 73.359, 23.672, 6.25, 5.078),
  NovaLeaf(24, 'leaf-24.png', 30.938, 19.844, 5, 9.062),
  NovaLeaf(25, 'leaf-25.png', 61.797, 20.781, 8.516, 4.766),
  NovaLeaf(26, 'leaf-26.png', 70.469, 18.125, 5.703, 3.906),
  NovaLeaf(27, 'leaf-27.png', 51.484, 16.875, 5.469, 6.094),
  NovaLeaf(28, 'leaf-28.png', 57.891, 16.953, 5.781, 5.703),
  NovaLeaf(29, 'leaf-29.png', 40.703, 15.547, 4.688, 6.094),
  NovaLeaf(30, 'leaf-30.png', 25.938, 16.094, 6.25, 4.375),
  NovaLeaf(31, 'leaf-31.png', 44.531, 15, 2.891, 5.781),
  NovaLeaf(32, 'leaf-32.png', 55.156, 12.578, 2.734, 4.219),
  NovaLeaf(33, 'leaf-33.png', 65.078, 9.375, 7.109, 9.922),
  NovaLeaf(34, 'leaf-34.png', 30.938, 8.516, 8.906, 11.016),
  NovaLeaf(35, 'leaf-35.png', 58.516, 10.391, 5.625, 6.719),
  NovaLeaf(36, 'leaf-36.png', 38.828, 7.422, 5.469, 7.344),
  NovaLeaf(37, 'leaf-37.png', 46.328, 2.891, 8.203, 15.937),
  NovaLeaf(38, 'leaf-38.png', 56.25, 5.312, 4.219, 6.719),
];
