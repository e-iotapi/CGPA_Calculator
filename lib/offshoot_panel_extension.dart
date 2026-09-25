part of 'home_page.dart';
// ignore_for_file: invalid_use_of_protected_member

extension OffshootPanelExtension on _MyHomePageState {
  Future<void> _toggleOffshootCourse(String id) async {
    final ex = offshootExcluded;
    ex.contains(id) ? ex.remove(id) : ex.add(id);
    await setOffshootExcluded(ex);
    setState(() {});
  }

  Future<void> _setOffshootDenominator(int v) async {
    await setOffshootOutOf(v);
    setState(() {});
  }

  Widget _denomChip(int value, bool selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _setOffshootDenominator(value),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: selected ? thm.highcolor.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? thm.highcolor : thm.bordcolor,
              width: selected ? 1.4 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value == 50 ? 'Best 5  ·  / 50' : 'All 6  ·  / 60',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? thm.highcolor : thm.textcolor,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildOffshootUI(double wid, double hei) {
    final rows = offshootRows();
    final counted = offshootCountedIds(rows).toSet();
    final total = offshootTotal(rows);
    final outOf = offshootOutOf;
    final scorableCount = rows.where((r) => r.scorable).length;

    return Expanded(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // ---- total ----
          Container(
            padding: EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: thm.cardcolor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: thm.bordcolor, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: thm.highcolor,
                      ),
                    ),
                    Text(
                      '  / $outOf',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        color: thm.textcolor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Offshoot total',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: thm.textcolor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              _denomChip(50, outOf == 50),
              SizedBox(width: 10),
              _denomChip(60, outOf == 60),
            ],
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Text(
              scorableCount < offshootTakeCount
                  ? 'Only $scorableCount of the ${offshootTakeCount} counted courses have a grade yet.'
                  : 'Counting the best $offshootTakeCount of your graded courses. Untick any a company does not ask for.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                color: thm.textcolor.withValues(alpha: 0.6),
              ),
            ),
          ),
          SizedBox(height: 4),

          // ---- the six courses ----
          for (final r in rows) _offshootRowTile(r, counted.contains(r.course.id)),
        ],
      ),
    );
  }

  Widget _offshootRowTile(OffshootRow r, bool isCounted) {
    final missing = r.grade == null;
    final label = missing ? '—' : gradecalc(r.grade!);
    final dim = r.excluded || !isCounted;

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _toggleOffshootCourse(r.course.id),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: thm.cardcolor.withValues(alpha: dim ? 0.45 : 1),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isCounted ? thm.highcolor : thm.bordcolor,
              width: isCounted ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                r.excluded
                    ? Icons.check_box_outline_blank
                    : Icons.check_box_outlined,
                size: 20,
                color: r.excluded ? thm.unscolor : thm.highcolor,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.course.id,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: thm.textcolor.withValues(alpha: dim ? 0.6 : 1),
                      ),
                    ),
                    Text(
                      r.course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 10.5,
                        color: thm.textcolor.withValues(alpha: dim ? 0.45 : 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                width: 42,
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        missing
                            ? thm.unscolor
                            : (isCounted
                                ? thm.highcolor
                                : thm.textcolor.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
