
.PHONY: game run lint

game: merged.moon
	tic ld39.tic -code merged.moon

merged.moon: prefix.moon game.moon map2.json
	cat prefix.moon > merged.moon
	moon convert_map.moon map2.json MAP_1 >> merged.moon
	cat game.moon >> merged.moon

run:
	moonc -p game.moon | lua -

lint: merged.moon
	moonc lint_config.moon
	moonc -l merged.moon
