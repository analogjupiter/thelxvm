module thelx.util;

///
auto ref T castTo(T, S)(auto ref S v) {
	return cast(T) v;
}
