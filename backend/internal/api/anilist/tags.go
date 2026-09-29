package anilist

type MediaTagMap map[int][]string

func MediaTagMapFromAnimeCollectionTags(data *AnimeCollectionTags) MediaTagMap {
	ret := make(MediaTagMap)
	if data == nil || data.GetMediaListCollection() == nil {
		return ret
	}

	for _, list := range data.GetMediaListCollection().GetLists() {
		if list == nil {
			continue
		}
		for _, entry := range list.GetEntries() {
			if entry == nil || entry.GetMedia() == nil {
				continue
			}
			for _, tag := range entry.GetMedia().GetTags() {
				if tag == nil {
					continue
				}
				ret.add(entry.GetMedia().GetID(), tag.GetName())
			}
		}
	}

	return ret
}

func MediaTagMapFromMangaCollectionTags(data *MangaCollectionTags) MediaTagMap {
	ret := make(MediaTagMap)
	if data == nil || data.GetMediaListCollection() == nil {
		return ret
	}

	for _, list := range data.GetMediaListCollection().GetLists() {
		if list == nil {
			continue
		}
		for _, entry := range list.GetEntries() {
			if entry == nil || entry.GetMedia() == nil {
				continue
			}
			for _, tag := range entry.GetMedia().GetTags() {
				if tag == nil {
					continue
				}
				ret.add(entry.GetMedia().GetID(), tag.GetName())
			}
		}
	}

	return ret
}

func (m MediaTagMap) add(mediaID int, tagName string) {
	if tagName == "" {
		return
	}

	existing := m[mediaID]
	for _, current := range existing {
		if current == tagName {
			return
		}
	}

	m[mediaID] = append(existing, tagName)
}
