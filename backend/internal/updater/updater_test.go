package updater

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestUpdater_GetLatestUpdateShouldFallback(t *testing.T) {
	fixture := newUpdaterTestFixture(t)
	websiteUrl = fixture.deadAPIURL

	u := fixture.newUpdater("2.0.2", nil)
	// update channel is "github"

	update, err := u.GetLatestUpdate()
	require.NoError(t, err)
	require.NotNilf(t, update, "update should contain the latest release")
	assert.Equal(t, fixture.release.TagName, update.Release.TagName)
	assert.Equal(t, MajorRelease, update.Type)
}

func TestUpdater_GetLatestUpdateSeanime(t *testing.T) {
	fixture := newUpdaterTestFixture(t)

	u := fixture.newUpdater("2.0.2", nil)
	u.UpdateChannel = "seanime"

	update, err := u.GetLatestUpdate()
	require.NoError(t, err)
	require.NotNilf(t, update, "update should contain the latest release")
	assert.Equal(t, fixture.release.TagName, update.Release.TagName)
	assert.Equal(t, MajorRelease, update.Type)
}

func TestUpdater_GetLatestUpdate(t *testing.T) {
	fixture := newUpdaterTestFixture(t)
	u := fixture.newUpdater(fixture.release.Version, nil)
	u.UpdateChannel = "seanime"

	update, err := u.GetLatestUpdate()
	require.NoError(t, err)
	require.Nil(t, update)
}
