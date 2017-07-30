
.PHONY: game run map

game: 
	tic ld39.tic -code game.moon

run: 
	moonc -p game.moon | lua -

map:
	moon convert_map.moon map1.json
