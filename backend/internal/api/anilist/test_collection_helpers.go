package anilist

import (
	"context"
	"fmt"
)

type AnimeCollectionEntryPatch struct {
	Status            *MediaListStatus
	Progress          *int
	Score             *float64
	Repeat            *int
	AiredEpisodes     *int
	NextAiringEpisode *BaseAnime_NextAiringEpisode
}

func PatchAnimeCollectionEntry(collection *AnimeCollection, mediaID int, patch AnimeCollectionEntryPatch) *AnimeCollection {
	if collection == nil {
		panic("anilist: anime collection is nil")
	}

	entry, currentList := findAnimeCollectionEntry(collection, mediaID)
	if entry == nil {
		panic(fmt.Sprintf("anilist: anime %d not found in collection; use EnsureAnimeCollectionEntry for missing media", mediaID))
	}

	if patch.Status != nil {
		currentList = moveAnimeEntryToStatus(collection, currentList, entry, *patch.Status)
		_ = currentList
	}

	applyAnimeCollectionEntryPatch(entry, patch)
	return collection
}

func EnsureAnimeCollectionEntry(collection *AnimeCollection, mediaID int, patch AnimeCollectionEntryPatch, client AnilistClient) *AnimeCollection {
	if collection == nil {
		panic("anilist: anime collection is nil")
	}
	if _, currentList := findAnimeCollectionEntry(collection, mediaID); currentList != nil {
		return collection
	}
	if client == nil {
		panic(fmt.Sprintf("anilist: cannot add anime %d without a client", mediaID))
	}
	if patch.Status == nil {
		panic(fmt.Sprintf("anilist: cannot add anime %d without a status", mediaID))
	}

	baseAnime, err := client.BaseAnimeByID(context.Background(), &mediaID)
	if err != nil {
		panic(err)
	}

	entry := &AnimeCollection_MediaListCollection_Lists_Entries{
		Media: baseAnime.GetMedia(),
	}
	list := ensureAnimeStatusList(collection, *patch.Status)
	list.Entries = append(list.Entries, entry)

	return PatchAnimeCollectionEntry(collection, mediaID, patch)
}

func PatchAnimeCollectionWithRelationsEntry(collection *AnimeCollectionWithRelations, mediaID int, patch AnimeCollectionEntryPatch) *AnimeCollectionWithRelations {
	if collection == nil {
		panic("anilist: anime collection with relations is nil")
	}

	entry, currentList := findAnimeCollectionWithRelationsEntry(collection, mediaID)
	if entry == nil {
		panic(fmt.Sprintf("anilist: anime %d not found in relation collection; use EnsureAnimeCollectionWithRelationsEntry for missing media", mediaID))
	}

	if patch.Status != nil {
		currentList = moveAnimeRelationsEntryToStatus(collection, currentList, entry, *patch.Status)
		_ = currentList
	}

	applyAnimeCollectionWithRelationsEntryPatch(entry, patch)
	return collection
}

func EnsureAnimeCollectionWithRelationsEntry(collection *AnimeCollectionWithRelations, mediaID int, patch AnimeCollectionEntryPatch, client AnilistClient) *AnimeCollectionWithRelations {
	if collection == nil {
		panic("anilist: anime collection with relations is nil")
	}
	if _, currentList := findAnimeCollectionWithRelationsEntry(collection, mediaID); currentList != nil {
		return collection
	}
	if client == nil {
		panic(fmt.Sprintf("anilist: cannot add anime %d without a client", mediaID))
	}
	if patch.Status == nil {
		panic(fmt.Sprintf("anilist: cannot add anime %d without a status", mediaID))
	}

	completeAnime, err := client.CompleteAnimeByID(context.Background(), &mediaID)
	if err != nil {
		panic(err)
	}

	entry := &AnimeCollectionWithRelations_MediaListCollection_Lists_Entries{
		Media: completeAnime.GetMedia(),
	}
	list := ensureAnimeRelationsStatusList(collection, *patch.Status)
	list.Entries = append(list.Entries, entry)

	return PatchAnimeCollectionWithRelationsEntry(collection, mediaID, patch)
}

func applyAnimeCollectionEntryPatch(entry *AnimeCollection_MediaListCollection_Lists_Entries, patch AnimeCollectionEntryPatch) {
	if patch.Status != nil {
		entry.Status = patch.Status
	}
	if patch.Progress != nil {
		entry.Progress = patch.Progress
	}
	if patch.Score != nil {
		entry.Score = patch.Score
	}
	if patch.Repeat != nil {
		entry.Repeat = patch.Repeat
	}
	if patch.AiredEpisodes != nil {
		entry.Media.Episodes = patch.AiredEpisodes
	}
	if patch.NextAiringEpisode != nil {
		entry.Media.NextAiringEpisode = patch.NextAiringEpisode
	}
}

func applyAnimeCollectionWithRelationsEntryPatch(entry *AnimeCollectionWithRelations_MediaListCollection_Lists_Entries, patch AnimeCollectionEntryPatch) {
	if patch.Status != nil {
		entry.Status = patch.Status
	}
	if patch.Progress != nil {
		entry.Progress = patch.Progress
	}
	if patch.Score != nil {
		entry.Score = patch.Score
	}
	if patch.Repeat != nil {
		entry.Repeat = patch.Repeat
	}
	if patch.AiredEpisodes != nil {
		entry.Media.Episodes = patch.AiredEpisodes
	}
}

func findAnimeCollectionEntry(collection *AnimeCollection, mediaID int) (*AnimeCollection_MediaListCollection_Lists_Entries, *AnimeCollection_MediaListCollection_Lists) {
	if collection == nil || collection.MediaListCollection == nil {
		return nil, nil
	}

	for _, list := range collection.MediaListCollection.Lists {
		if list == nil || list.Entries == nil {
			continue
		}
		for _, entry := range list.Entries {
			if entry != nil && entry.GetMedia().GetID() == mediaID {
				return entry, list
			}
		}
	}

	return nil, nil
}

func findAnimeCollectionWithRelationsEntry(collection *AnimeCollectionWithRelations, mediaID int) (*AnimeCollectionWithRelations_MediaListCollection_Lists_Entries, *AnimeCollectionWithRelations_MediaListCollection_Lists) {
	if collection == nil || collection.MediaListCollection == nil {
		return nil, nil
	}

	for _, list := range collection.MediaListCollection.Lists {
		if list == nil || list.Entries == nil {
			continue
		}
		for _, entry := range list.Entries {
			if entry != nil && entry.GetMedia().GetID() == mediaID {
				return entry, list
			}
		}
	}

	return nil, nil
}

func moveAnimeEntryToStatus(collection *AnimeCollection, currentList *AnimeCollection_MediaListCollection_Lists, entry *AnimeCollection_MediaListCollection_Lists_Entries, status MediaListStatus) *AnimeCollection_MediaListCollection_Lists {
	if currentList != nil && currentList.Status != nil && *currentList.Status == status {
		return currentList
	}
	if currentList != nil {
		removeAnimeEntry(currentList, entry.GetMedia().GetID())
	}

	target := ensureAnimeStatusList(collection, status)
	target.Entries = append(target.Entries, entry)
	return target
}

func moveAnimeRelationsEntryToStatus(collection *AnimeCollectionWithRelations, currentList *AnimeCollectionWithRelations_MediaListCollection_Lists, entry *AnimeCollectionWithRelations_MediaListCollection_Lists_Entries, status MediaListStatus) *AnimeCollectionWithRelations_MediaListCollection_Lists {
	if currentList != nil && currentList.Status != nil && *currentList.Status == status {
		return currentList
	}
	if currentList != nil {
		removeAnimeRelationsEntry(currentList, entry.GetMedia().GetID())
	}

	target := ensureAnimeRelationsStatusList(collection, status)
	target.Entries = append(target.Entries, entry)
	return target
}

func ensureAnimeStatusList(collection *AnimeCollection, status MediaListStatus) *AnimeCollection_MediaListCollection_Lists {
	if collection.MediaListCollection == nil {
		collection.MediaListCollection = &AnimeCollection_MediaListCollection{}
	}

	for _, list := range collection.MediaListCollection.Lists {
		if list != nil && list.Status != nil && *list.Status == status {
			if list.Entries == nil {
				list.Entries = []*AnimeCollection_MediaListCollection_Lists_Entries{}
			}
			return list
		}
	}

	name := string(status)
	isCustomList := false
	list := &AnimeCollection_MediaListCollection_Lists{
		Status:       testPointer(status),
		Name:         &name,
		IsCustomList: &isCustomList,
		Entries:      []*AnimeCollection_MediaListCollection_Lists_Entries{},
	}
	collection.MediaListCollection.Lists = append(collection.MediaListCollection.Lists, list)
	return list
}

func ensureAnimeRelationsStatusList(collection *AnimeCollectionWithRelations, status MediaListStatus) *AnimeCollectionWithRelations_MediaListCollection_Lists {
	if collection.MediaListCollection == nil {
		collection.MediaListCollection = &AnimeCollectionWithRelations_MediaListCollection{}
	}

	for _, list := range collection.MediaListCollection.Lists {
		if list != nil && list.Status != nil && *list.Status == status {
			if list.Entries == nil {
				list.Entries = []*AnimeCollectionWithRelations_MediaListCollection_Lists_Entries{}
			}
			return list
		}
	}

	name := string(status)
	isCustomList := false
	list := &AnimeCollectionWithRelations_MediaListCollection_Lists{
		Status:       testPointer(status),
		Name:         &name,
		IsCustomList: &isCustomList,
		Entries:      []*AnimeCollectionWithRelations_MediaListCollection_Lists_Entries{},
	}
	collection.MediaListCollection.Lists = append(collection.MediaListCollection.Lists, list)
	return list
}

func removeAnimeEntry(list *AnimeCollection_MediaListCollection_Lists, mediaID int) {
	for idx, entry := range list.GetEntries() {
		if entry != nil && entry.GetMedia().GetID() == mediaID {
			list.Entries = append(list.Entries[:idx], list.Entries[idx+1:]...)
			return
		}
	}
}

func removeAnimeRelationsEntry(list *AnimeCollectionWithRelations_MediaListCollection_Lists, mediaID int) {
	for idx, entry := range list.GetEntries() {
		if entry != nil && entry.GetMedia().GetID() == mediaID {
			list.Entries = append(list.Entries[:idx], list.Entries[idx+1:]...)
			return
		}
	}
}

func testPointer[T any](value T) *T {
	return &value
}
