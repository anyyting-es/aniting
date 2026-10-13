package db_bridge

import (
	"errors"
	"seanime/internal/database/db"
	"seanime/internal/database/models"
	"seanime/internal/library/shows"

	"github.com/goccy/go-json"
	"github.com/samber/mo"
	"gorm.io/gorm"
)

var CurrShowLocalFilesDbId uint
var CurrShowLocalFiles mo.Option[[]*shows.ShowLocalFile]

// GetShowLocalFiles will return the latest show local files and the id of the entry.
func GetShowLocalFiles(db *db.Database) ([]*shows.ShowLocalFile, uint, error) {
	if CurrShowLocalFiles.IsPresent() {
		return CurrShowLocalFiles.MustGet(), CurrShowLocalFilesDbId, nil
	}

	// Get the latest entry
	var res models.ShowLocalFiles
	err := db.Gorm().Last(&res).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			CurrShowLocalFiles = mo.Some([]*shows.ShowLocalFile{})
			CurrShowLocalFilesDbId = 0
			return []*shows.ShowLocalFile{}, 0, nil
		}
		return nil, 0, err
	}

	// Unmarshal the local files
	lfsBytes := res.Value
	var lfs []*shows.ShowLocalFile
	if err := json.Unmarshal(lfsBytes, &lfs); err != nil {
		return nil, 0, err
	}

	db.Logger.Debug().Msg("db: Show local files retrieved")

	CurrShowLocalFiles = mo.Some(lfs)
	CurrShowLocalFilesDbId = res.ID

	return lfs, res.ID, nil
}

// SaveShowLocalFiles will save the show local files in the database at the given id.
func SaveShowLocalFiles(db *db.Database, lfsId uint, lfs []*shows.ShowLocalFile) ([]*shows.ShowLocalFile, error) {
	// Marshal the local files
	marshaledLfs, err := json.Marshal(lfs)
	if err != nil {
		return nil, err
	}

	// Save the local files
	ret, err := db.UpsertShowLocalFiles(&models.ShowLocalFiles{
		BaseModel: models.BaseModel{
			ID: lfsId,
		},
		Value: marshaledLfs,
	})
	if err != nil {
		return nil, err
	}

	CurrShowLocalFiles = mo.Some(lfs)
	CurrShowLocalFilesDbId = ret.ID

	db.Logger.Debug().Msg("db: Show local files saved")

	return lfs, nil
}
