#include "RadioStationsModel.h"

RadioStationsModel::RadioStationsModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int RadioStationsModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_stations.size();
}

QVariant RadioStationsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_stations.size()) return QVariant();

    const RadioStation &station = m_stations.at(index.row());
    switch (role) {
    case StationIdRole:
        return station.stationId;
    case NameRole:
        return station.name;
    case StreamUrlRole:
        return station.streamUrl;
    case FaviconRole:
        return station.favicon;
    case TagsRole:
        return station.tags;
    case CountryRole:
        return station.country;
    case LanguageRole:
        return station.language;
    case CodecRole:
        return station.codec;
    case BitrateRole:
        return station.bitrate;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> RadioStationsModel::roleNames() const
{
    return {
        { StationIdRole, "stationId" },
        { NameRole, "name" },
        { StreamUrlRole, "streamUrl" },
        { FaviconRole, "favicon" },
        { TagsRole, "tags" },
        { CountryRole, "country" },
        { LanguageRole, "language" },
        { CodecRole, "codec" },
        { BitrateRole, "bitrate" }
    };
}

void RadioStationsModel::setStations(const QVector<RadioStation> &stations)
{
    beginResetModel();
    m_stations = stations;
    endResetModel();
}

const RadioStation *RadioStationsModel::stationAt(int index) const
{
    if (index < 0 || index >= m_stations.size()) return nullptr;
    return &m_stations.at(index);
}

void RadioStationsModel::clear()
{
    beginResetModel();
    m_stations.clear();
    endResetModel();
}
