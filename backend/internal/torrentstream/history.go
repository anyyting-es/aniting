package torrentstream

import (
	"seanime/internal/database/db_bridge"
	"seanime/internal/events"
	hibiketorrent "seanime/internal/extension/hibike/torrent"
	"seanime/internal/util"

	"github.com/5rahim/habari"
)

type BatchHistoryResponse struct {
	Torrent           *hibiketorrent.AnimeTorrent      `json:"torrent"`
	Metadata          *habari.Metadata                 `json:"metadata"`
	BatchEpisodeFiles *hibiketorrent.BatchEpisodeFiles `json:"batchEpisodeFiles"`
}

func (r *Repository) GetBatchHistory(mId int) (ret *BatchHistoryResponse) {
	defer util.HandlePanicInModuleThen("torrentstream/GetBatchHistory", func() {
		ret = &BatchHistoryResponse{}
	})

	torrent, batchFiles, err := db_bridge.GetTorrentstreamHistory(r.db, mId)
	if err != nil {
		return &BatchHistoryResponse{}
	}

	metadata := habari.Parse(torrent.Name)

	return &BatchHistoryResponse{
		torrent,
		metadata,
		batchFiles,
	}
}

func (r *Repository) AddBatchHistory(mId int, torrent *hibiketorrent.AnimeTorrent, files *hibiketorrent.BatchEpisodeFiles) {
	go func() {
		defer util.HandlePanicInModuleThen("torrentstream/AddBatchHistory", func() {})

		if mId == 0 || torrent == nil {
			return
		}

		_ = db_bridge.InsertTorrentstreamHistory(r.db, mId, torrent, files)

		r.wsEventManager.SendEvent(events.InvalidateQueries, []string{events.GetTorrentstreamBatchHistoryEndpoint})
	}()
}

func (r *Repository) DeleteBatchHistory(mId int) (err error) {
	defer util.HandlePanicInModuleWithError("torrentstream/DeleteBatchHistory", &err)

	if mId == 0 {
		return nil
	}

	err = db_bridge.DeleteTorrentstreamHistory(r.db, mId)
	if err != nil {
		return err
	}

	r.wsEventManager.SendEvent(events.InvalidateQueries, []string{events.GetTorrentstreamBatchHistoryEndpoint})

	return nil
}
